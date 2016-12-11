# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mail/gpg/version'

Gem::Specification.new do |spec|
  spec.name          = "mail-gpg"
  spec.version       = Mail::Gpg::VERSION
  spec.authors       = ["Jens Kraemer"]
  spec.email         = ["jk@jkraemer.net"]
  spec.description   = "GPG/MIME encryption plugin for the Ruby Mail Library\nThis tiny gem adds GPG capabilities to Mail::Message and ActionMailer::Base. Because privacy matters."
  spec.summary       = %q{GPG/MIME encryption plugin for the Ruby Mail Library}
  spec.homepage      = "https://github.com/jkraemer/mail-gpg"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "mail", "~> 2.5", ">= 2.5.3"
  spec.add_dependency "gpgme", "~> 2.0", ">= 2.0.2"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "test-unit", "~> 3.0"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "actionmailer", ">= 3.2.0"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "shoulda-context", '~> 1.1'
end
