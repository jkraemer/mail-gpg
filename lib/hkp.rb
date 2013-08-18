require 'open-uri'
class Hkp
  def initialize(keyserver = 'http://pool.sks-keyservers.net:11371')
    @keyserver = keyserver
  end

  def search(name)
    [].tap do |results|
      open("#{@keyserver}/pks/lookup?options=mr&search=#{URI.escape name}") do |f|
        f.each_line do |l|
          if l =~ /pub:(\w{8}):/
            results << $1
          end
        end
      end
    end
  end

  def fetch(id)
    open("#{@keyserver}/pks/lookup?options=mr&op=get&search=0x#{URI.escape id}") do |f|
      return clean_key f.read
    end

  end

  private
  def clean_key(key)
    if key =~ /(-----BEGIN PGP PUBLIC KEY BLOCK-----.*-----END PGP PUBLIC KEY BLOCK-----)/m
      return $1
    end
  end

end
