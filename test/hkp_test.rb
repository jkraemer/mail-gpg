require 'test_helper'
require 'byebug'
require 'hkp'

class HkpTest < MailGpgTestCase

  context "hkp client" do
    {
      "http://pool.sks-keyservers.net:11371" => {
        host: 'pool.sks-keyservers.net',
        ssl: false,
        port: 11371
      },
      "https://hkps.pool.sks-keyservers.net" => {
        host: 'hkps.pool.sks-keyservers.net',
        ssl: true,
        port: 443
      },
      "hkp://pool.sks-keyservers.net" => {
        host: 'pool.sks-keyservers.net',
        ssl: false,
        port: 11371
      },
      "hkps://hkps.pool.sks-keyservers.net" => {
        host: 'hkps.pool.sks-keyservers.net',
        ssl: true,
        port: 443
      },
    }.each do |url, data|

      context "with server #{url}" do

        context 'client setup' do

          setup do
            @client = Hkp::Client.new url
          end

          should "have correct port" do
            assert_equal data[:port], @client.instance_variable_get("@port")
          end

          should "have correct ssl setting" do
            assert_equal data[:ssl], @client.instance_variable_get("@use_ssl")
          end

          should "have correct host" do
            assert_equal data[:host], @client.instance_variable_get("@host")
          end

        end

        if ENV['ONLINE_TESTS']

          context 'key search' do

            setup do
              @hkp = Hkp.new keyserver: url,
                             ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
            end

            should 'find key' do
              assert result = @hkp.search('jk@jkraemer.net')
              assert result.size > 0
            end

            should 'fetch key' do
              assert result = @hkp.fetch('584C8BEE17CAC560')
              assert_match 'PGP PUBLIC KEY BLOCK', result
            end

          end

        end

      end
    end
  end

  context 'key search' do

    context "without keyserver url" do
      setup do
        @hkp = Hkp.new
      end

      should "have a non-empty keyserver" do
        assert url = @hkp.instance_variable_get("@keyserver")
        assert !url.blank?
      end

      if ENV['ONLINE_TESTS']
        should 'find key' do
          assert result = @hkp.search('jk@jkraemer.net')
          assert result.size > 0
        end
      end
    end

  end

  context 'with mocked server' do
    setup do
      WebMock.disable_net_connect!
      @keyserver = 'hkp://keys.example.com'
      @hkp = Hkp.new(keyserver: @keyserver)
    end

    teardown do
      WebMock.allow_net_connect!
    end

    context 'search' do
      should 'include op=index parameter in request' do
        stub_request(:get, "http://keys.example.com:11371/pks/lookup")
          .with(query: hash_including('op' => 'index'))
          .to_return(status: 200, body: "info:1:1\npub:ABC123:1:2048:1234567890::\nuid:Test User <test@example.com>:1234567890::")

        result = @hkp.search('test@example.com')
        assert_requested :get, "http://keys.example.com:11371/pks/lookup",
          query: hash_including('op' => 'index', 'search' => 'test@example.com')
      end

      should 'properly encode special characters in search query' do
        stub_request(:get, /keys\.example\.com/)
          .to_return(status: 200, body: "info:1:1\npub:ABC123:1:2048:1234567890::\n")

        @hkp.search('test+user@example.com')

        # Should use proper URL encoding, + should become %2B
        assert_requested :get, "http://keys.example.com:11371/pks/lookup",
          query: hash_including('search' => 'test+user@example.com')
      end

      should 'parse machine readable response' do
        stub_request(:get, /keys\.example\.com/)
          .to_return(status: 200, body: <<~RESPONSE)
            info:1:2
            pub:ABC123DEF456:1:2048:1234567890::
            uid:Test User <test@example.com>:1234567890::
            pub:789GHI012JKL:1:4096:1234567891::
            uid:Another User <another@example.com>:1234567891::
          RESPONSE

        result = @hkp.search('example.com')

        assert_equal 2, result.size
        assert_equal 'ABC123DEF456', result[0][0]
        assert_equal '789GHI012JKL', result[1][0]
      end

      should 'return empty array when no keys found' do
        stub_request(:get, /keys\.example\.com/)
          .to_return(status: 200, body: "info:1:0\n")

        result = @hkp.search('nonexistent@example.com')

        assert_equal [], result
      end

      should 'raise error on server error when raise_errors is true' do
        stub_request(:get, /keys\.example\.com/)
          .to_return(status: 500, body: "Internal Server Error")

        assert_raises(Hkp::InvalidResponse) do
          @hkp.search('test@example.com')
        end
      end

      should 'return nil on server error when raise_errors is false' do
        hkp = Hkp.new(keyserver: @keyserver, raise_errors: false)
        stub_request(:get, /keys\.example\.com/)
          .to_return(status: 500, body: "Internal Server Error")

        result = hkp.search('test@example.com')

        assert_nil result
      end
    end

    context 'fetch' do
      should 'include op=get parameter in request' do
        stub_request(:get, "http://keys.example.com:11371/pks/lookup")
          .with(query: hash_including('op' => 'get'))
          .to_return(status: 200, body: <<~KEY)
            -----BEGIN PGP PUBLIC KEY BLOCK-----
            mQENBFxxxxxxx
            -----END PGP PUBLIC KEY BLOCK-----
          KEY

        result = @hkp.fetch('ABC123')
        assert_requested :get, "http://keys.example.com:11371/pks/lookup",
          query: hash_including('op' => 'get', 'search' => '0xABC123')
      end

      should 'properly encode key id with special characters' do
        stub_request(:get, /keys\.example\.com/)
          .to_return(status: 200, body: <<~KEY)
            -----BEGIN PGP PUBLIC KEY BLOCK-----
            mQENBFxxxxxxx
            -----END PGP PUBLIC KEY BLOCK-----
          KEY

        # Key IDs shouldn't normally have special chars, but testing encoding anyway
        @hkp.fetch('ABC+123')

        assert_requested :get, "http://keys.example.com:11371/pks/lookup",
          query: hash_including('search' => '0xABC+123')
      end

      should 'extract key from response' do
        stub_request(:get, /keys\.example\.com/)
          .to_return(status: 200, body: <<~RESPONSE)
            Some header text
            -----BEGIN PGP PUBLIC KEY BLOCK-----

            mQENBFxxxxxxx
            =xxxx
            -----END PGP PUBLIC KEY BLOCK-----
            Some footer text
          RESPONSE

        result = @hkp.fetch('ABC123')

        assert result.start_with?('-----BEGIN PGP PUBLIC KEY BLOCK-----')
        assert result.end_with?('-----END PGP PUBLIC KEY BLOCK-----')
        refute result.include?('Some header text')
        refute result.include?('Some footer text')
      end

      should 'return nil when key not found' do
        stub_request(:get, /keys\.example\.com/)
          .to_return(status: 404, body: "Not Found")

        hkp = Hkp.new(keyserver: @keyserver, raise_errors: false)
        result = hkp.fetch('NONEXISTENT')

        assert_nil result
      end

      should 'return nil when response has no valid key block' do
        stub_request(:get, /keys\.example\.com/)
          .to_return(status: 200, body: "No key here")

        result = @hkp.fetch('ABC123')

        assert_nil result
      end
    end

    context 'redirects' do
      should 'follow same-host redirects' do
        stub_request(:get, "http://keys.example.com:11371/pks/lookup")
          .with(query: hash_including('op' => 'index', 'search' => 'test'))
          .to_return(status: 302, headers: { 'Location' => '/pks/lookup?op=index&options=mr&search=test&new=1' })

        stub_request(:get, "http://keys.example.com:11371/pks/lookup")
          .with(query: hash_including('op' => 'index', 'new' => '1'))
          .to_return(status: 200, body: "info:1:1\npub:ABC123:1:2048:1234567890::\n")

        result = @hkp.search('test')
        assert_equal 1, result.size
        assert_equal 'ABC123', result[0][0]
      end

      should 'follow cross-host redirects' do
        stub_request(:get, "http://keys.example.com:11371/pks/lookup")
          .with(query: hash_including('op' => 'index'))
          .to_return(status: 302, headers: { 'Location' => 'http://keys2.example.com/pks/lookup?op=index&options=mr&search=test' })

        stub_request(:get, "http://keys2.example.com:80/pks/lookup")
          .with(query: hash_including('op' => 'index'))
          .to_return(status: 200, body: "info:1:1\npub:DEF456:1:2048:1234567890::\n")

        result = @hkp.search('test')
        assert_equal 1, result.size
        assert_equal 'DEF456', result[0][0]
      end

      should 'raise TooManyRedirects after MAX_REDIRECTS' do
        stub_request(:get, /keys\.example\.com/)
          .to_return(status: 302, headers: { 'Location' => 'http://keys.example.com:11371/pks/lookup?op=index&search=test' })

        assert_raises(Hkp::TooManyRedirects) do
          @hkp.search('test')
        end
      end
    end
  end

  context 'lookup_keyserver' do
    setup do
      WebMock.disable_net_connect!
    end

    teardown do
      WebMock.allow_net_connect!
    end

    should 'decode percent-encoded keyserver URL from gpgconf' do
      # Create a testable subclass that stubs exec_cmd
      hkp_class = Class.new(Hkp) do
        def exec_cmd(cmd)
          if cmd.include?('gpgconf --list-options')
            # Simulated gpgconf output with percent-encoded URL
            # Format: name:flags:value (value may be quoted)
            "keyserver:0:hkp%3A%2F%2Fkeys.example.com\n"
          else
            nil
          end
        end
      end

      hkp = hkp_class.new
      keyserver = hkp.instance_variable_get('@keyserver')
      assert_equal 'hkp://keys.example.com', keyserver
    end
  end

end
