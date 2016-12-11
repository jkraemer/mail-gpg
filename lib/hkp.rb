require 'gpgme'
require 'openssl'
require 'net/http'

# simple HKP client for public key search and retrieval
class Hkp

  class TooManyRedirects < StandardError; end

  class InvalidResponse < StandardError; end


  class Client

    MAX_REDIRECTS = 3

    def initialize(server, ssl_verify_mode: OpenSSL::SSL::VERIFY_PEER)
      uri = URI server
      @host = uri.host
      @port = uri.port
      @use_ssl = false
      @ssl_verify_mode = ssl_verify_mode

      # set port and ssl flag according to URI scheme
      case uri.scheme.downcase
      when 'hkp'
        # use the HKP default port unless another port has been given
        @port ||= 11371
      when /\A(hkp|http)s\z/
        # hkps goes through 443 by default
        @port ||= 443
        @use_ssl = true
      end
      @port ||= 80
    end


    def get(path, redirect_depth = 0)
      Net::HTTP.start @host, @port, use_ssl: @use_ssl,
                                    verify_mode: @ssl_verify_mode do |http|

        request = Net::HTTP::Get.new path
        response = http.request request

        case response.code.to_i
        when 200
          return response.body
        when 301, 302
          if redirect_depth >= MAX_REDIRECTS
            raise TooManyRedirects
          else
            http_get response['location'], redirect_depth + 1
          end
        else
          raise InvalidResponse, response.code
        end

      end
    end

  end


  def initialize(options = {})
    if String === options
      options = { keyserver: options }
    end
    @keyserver = options.delete(:keyserver) || lookup_keyserver || 'http://pool.sks-keyservers.net:11371'
    @options = { raise_errors: true }.merge options
  end

  def raise_errors?
    !!@options[:raise_errors]
  end

  #
  # hkp.search 'user@host.com'
  # will return an array of arrays, one for each matching key found, containing
  # the key id as the first elment and any further info returned by the key
  # server in the following elements.
  # see http://tools.ietf.org/html/draft-shaw-openpgp-hkp-00#section-5.2 for
  # what that *might* be. unfortunately key servers seem to differ in how much
  # and what info they return besides the key id
  def search(name)
    [].tap do |results|
      result = hkp_client.get "/pks/lookup?options=mr&search=#{URI.escape name}"

      result.each_line do |l|
        components = l.strip.split(':')
        if components.shift == 'pub'
          results << components
        end
      end if result
    end

  rescue
    raise $! if raise_errors?
    nil
  end


  # returns the key data as returned from the server as a string
  def fetch(id)
    result = hkp_client.get "/pks/lookup?options=mr&op=get&search=0x#{URI.escape id}"
    return clean_key(result) if result

  rescue Exception
    raise $! if raise_errors?
    nil
  end


  # fetches key data by id and imports the found key(s) into GPG, returning the full hex fingerprints of the
  # imported key(s) as an array. Given there are no collisions with the id given / the server has returned
  # exactly one key this will be a one element array.
  def fetch_and_import(id)
    if key = fetch(id)
      GPGME::Key.import(key).imports.map(&:fpr)
    end
  rescue Exception
    raise $! if raise_errors?
  end

  private

  def hkp_client
    @hkp_client ||= Client.new @keyserver, ssl_verify_mode: @options[:ssl_verify_mode]
  end

  def clean_key(key)
    if key =~ /(-----BEGIN PGP PUBLIC KEY BLOCK-----.*-----END PGP PUBLIC KEY BLOCK-----)/m
      return $1
    end
  end

  def exec_cmd(cmd)
    res = `#{cmd}`
    return nil if $?.exitstatus != 0
    res
  end

  def lookup_keyserver
    url = nil
    if res = exec_cmd("gpgconf --list-options gpgs 2>&1 | grep keyserver 2>&1")
      url = URI.decode(res.split(":").last.split("\"").last.strip)
    elsif res = exec_cmd("gpg --gpgconf-list 2>&1 | grep gpgconf-gpg.conf 2>&1")
      conf_file = res.split(":").last.split("\"").last.strip
      if res = exec_cmd("cat #{conf_file} 2>&1 | grep ^keyserver 2>&1")
        url = res.split(" ").last.strip
      end
    end
    url =~ /^(http|hkp)/ ? url : nil
  end

end

