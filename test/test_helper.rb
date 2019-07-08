require 'open3'
require 'test/unit'
require 'shoulda/context'
require 'mail-gpg'
require 'action_mailer'
require 'securerandom'
require 'byebug'

Mail.defaults do
  delivery_method :test
end
ActionMailer::Base.delivery_method = :test

class MailGpgTestCase < Test::Unit::TestCase
  def setup
    @gpg_utils = GPGTestUtils.new(ENV['GPG_BIN'])
    @gpg_utils.setup
  end

  def set_passphrase(*args)
    @gpg_utils.set_passphrase(*args)
  end
end

class GPGTestUtils
  attr_reader :gpg_engine

  def initialize(gpg_bin = nil)
    @home = File.join File.dirname(__FILE__), 'gpghome'
    @gpg_bin = gpg_bin

    ENV['GPG_AGENT_INFO'] = '' # disable gpg agent
    ENV['GNUPGHOME'] = @home

    if @gpg_bin
      GPGME::Engine.set_info(GPGME::PROTOCOL_OpenPGP, @gpg_bin, @home)
    else
      GPGME::Engine.home_dir = @home
    end

    @gpg_engine = GPGME::Engine.info.find {|e| e.protocol == GPGME::PROTOCOL_OpenPGP }
    @gpg_bin ||= @gpg_engine.file_name

    if Gem::Version.new(@gpg_engine.version) >= Gem::Version.new("2.1.0")
      @preset_passphrases = true
    else
      @preset_passphrases = false
    end
  end

  def preset_passphrases?
    !!@preset_passphrases
  end

  def setup
    gen_keys unless File.directory? @home

    if @preset_passphrases
      libexecdir = `gpgconf --list-dir`.lines.grep(/^libexecdir:/).first.split(':').last.strip
      @gpp_bin = File.join(libexecdir, 'gpg-preset-passphrase')
      @keygrip_jane = get_keygrip('jane@foo.bar')
      @keygrip_joe = get_keygrip('joe@foo.bar')
    end

  end

  def gen_keys
    puts "setting up keydir #{@home}"
    FileUtils.mkdir_p @home
    (File.open(File.join(@home, "gpg-agent.conf"), "wb") << "allow-preset-passphrase\nbatch\n").close
    GPGME::Ctx.new do |gpg|
      gpg.generate_key <<-END
<GnupgKeyParms format="internal">
  Key-Type: DSA
  Key-Length: 1024
  Subkey-Type: ELG-E
  Subkey-Length: 1024
  Name-Real: Joe Tester
  Name-Comment: with stupid passphrase
  Name-Email: joe@foo.bar
  Expire-Date: 0
  Passphrase: abc
</GnupgKeyParms>
END
      gpg.generate_key <<-END
<GnupgKeyParms format="internal">
  Key-Type: DSA
  Key-Length: 1024
  Subkey-Type: ELG-E
  Subkey-Length: 1024
  Name-Real: Jane Doe
  Name-Comment: with stupid passphrase
  Name-Email: jane@foo.bar
  Expire-Date: 0
  Passphrase: abc
</GnupgKeyParms>
END
    end
  end

  # Put passphrase into gpg-agent (required with GnuPG v2).
  def set_passphrase(passphrase)
    if preset_passphrases?
      ensure_gpg_agent
      call_gpp(@keygrip_jane, passphrase)
      call_gpp(@keygrip_joe, passphrase)
    end
  end

  private

  def get_keygrip(uid)
    `#{@gpg_bin} --list-secret-keys --with-colons #{uid} 2>&1`.lines.grep(/^grp/).first.split(':')[9]
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
    output, status = Open3.capture2e(@gpp_bin, '--homedir', ENV['GNUPGHOME'], '--preset', keygrip, {stdin_data: passphrase})
    if ! output.empty?
      $stderr.puts "#{@gpp_bin} returned status #{status.exitstatus}: #{output}"
    end
  end
end

gpg_utils = GPGTestUtils.new(ENV['GPG_BIN'])
v = Gem::Version.new(gpg_utils.gpg_engine.version)
if v >= Gem::Version.new("2.1.0")
  puts "Running with GPG >= 2.1"
elsif v >= Gem::Version.new("2.0.0")
  puts "Running with GPG 2.0, this isn't going well since we cannot set passphrases non-interactively"
else
  puts "Running with GPG < 2.0"
end
gpg_utils.setup

