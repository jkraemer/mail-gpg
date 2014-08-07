require 'open-uri'
require 'gpgme'

# simple HKP client for public key retrieval
class Hkp
  def initialize(keyserver = nil)
    @keyserver = keyserver || lookup_keyserver || 'http://pool.sks-keyservers.net:11371'
  end

  # hkp.search 'user@host.com'
  # will return an array of arrays, one for each matching key found, containing
  # the key id as the first elment and any further info returned by the key
  # server in the following elements.
  # see http://tools.ietf.org/html/draft-shaw-openpgp-hkp-00#section-5.2 for
  # what that *might* be. unfortunately key servers seem to differ in how much
  # and what info they return besides the key id
  def search(name)
    [].tap do |results|
      open("#{@keyserver}/pks/lookup?options=mr&search=#{URI.escape name}") do |f|
        f.each_line do |l|
          components = l.strip.split(':')
          if components.shift == 'pub'
            results << components
          end
        end
      end
    end
  end

  # returns the key data as returned from the server as a string
  def fetch(id)
    open("#{@keyserver}/pks/lookup?options=mr&op=get&search=0x#{URI.escape id}") do |f|
      return clean_key f.read
    end
  rescue Exception
    nil
  end

  # fetches key data by id and imports the found key(s) into GPG, returning the full hex fingerprints of the
  # imported key(s) as an array. Given there are no collisions with the id given / the server has returned
  # exactly one key this will be a one element array.
  def fetch_and_import(id)
    if key = fetch(id)
      GPGME::Key.import(key).imports.map(&:fpr)
    end
  end

  private
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
