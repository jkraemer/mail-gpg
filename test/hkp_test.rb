require 'test_helper'
require 'byebug'
require 'hkp'

class HkpTest < Test::Unit::TestCase

  context "hpk client key server setup" do
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

  context 'key search' do

    context "without keyserver url" do
      setup do
        @hkp = Hkp.new
      end

      should "have a non-empty keyserver" do
        assert url = @hkp.instance_variable_get("@keyserver")
        assert !url.blank?
      end

      should 'find key' do
        assert result = @hkp.search('jk@jkraemer.net')
        assert result.size > 0
      end
    end

  end

end
