require 'open3'
require 'test/unit'
require 'shoulda/context'
require 'mail-gpg'
require 'action_mailer'
require 'securerandom'

begin
  require 'pry-nav'
rescue LoadError
end

Mail.defaults do
  delivery_method :test
end
ActionMailer::Base.delivery_method = :test

def get_keygrip(uid)
  `gpg --list-secret-keys --with-colons #{uid} 2>&1`.lines.grep(/^grp/).first.split(':')[9]
end

# Test for and set up GnuPG v2.1
gpg_engine = GPGME::Engine.info.find {|e| e.protocol == GPGME::PROTOCOL_OpenPGP }
if Gem::Version.new(gpg_engine.version) >= Gem::Version.new("2.1.0")
  GPG21 = true
  libexecdir = `gpgconf --list-dir`.lines.grep(/^libexecdir:/).first.split(':').last.strip
  GPPBIN = File.join(libexecdir, 'gpg-preset-passphrase')
  KEYGRIP_JANE = get_keygrip('jane@foo.bar')
  KEYGRIP_JOE = get_keygrip('joe@foo.bar')
else
  GPG21 = false
end

# Put passphrase into gpg-agent (required with GnuPG v2).
def set_passphrase(passphrase)
  if GPG21
    ensure_gpg_agent
    call_gpp(KEYGRIP_JANE, passphrase)
    call_gpp(KEYGRIP_JOE, passphrase)
  end
end

def ensure_gpg_agent
  # Make sure the gpg-agent is running (doesn't start automatically when
  # gpg-preset-passphrase is calling).
  output = `gpgconf --launch gpg-agent 2>&1`
  if ! output.empty?
    $stderr.puts "Launching gpg-agent returned: #{output}"
  end
end

def call_gpp(keygrip, passphrase)
  output, status = Open3.capture2e(GPPBIN, '--homedir', ENV['GNUPGHOME'], '--preset', keygrip, {stdin_data: passphrase})
  if ! output.empty?
    $stderr.puts "#{GPPBIN} returned status #{status.exitstatus}: #{output}"
  end
end
