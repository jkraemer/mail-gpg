# Mail::Gpg

This gem adds GPG/MIME encryption capabilities to the [Ruby Mail
Library](https://github.com/mikel/mail)

## Installation

Add this line to your application's Gemfile:

    gem 'mail-gpg', require: 'mail/gpg'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mail-gpg


## Usage

Construct your Mail object as usual and hand it to `Mail::Gpg.encrypt` to get
an encrypted Mail::Message object:

    m = Mail.new do
      to 'jane@doe.net'
      from 'john@doe.net'
      subject 'gpg test'
      body "encrypt me!"
      add_file "some_attachment.zip"
    end
    Mail::Gpg.encrypt(m).deliver

Make sure all recipients' public keys are in your local gpg keychain.


## Todo

* Signing of encrypted / unencrypted mails
* Add optional on the fly import of recipients' keys from public key servers based on email address
* Send encrypted mails to recipients when possible, fall back to unencrypted
  mail otherwiese
* Ease and document usage with Rails' ActionMailer


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


