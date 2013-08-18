require "bundler/gem_tasks"
require 'rake/testtask'
require 'gpgme'

def setup_gpghome
  gpghome = File.join File.dirname(__FILE__), 'test', 'gpghome'
  ENV['GNUPGHOME'] = gpghome
  unless File.directory? gpghome
    FileUtils.mkdir_p gpghome
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
end

task :default => [:test]
Rake::TestTask.new(:test) do |test|
  setup_gpghome
  test.libs << 'test'
  test.test_files = FileList['test/**/*_test.rb']
  test.verbose = true
end

