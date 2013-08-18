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

### Encrypting / Signing
Construct your Mail object as usual and hand it to `Mail::Gpg.encrypt` to get
an encrypted Mail::Message object:

    m = Mail.new do
      to 'jane@doe.net'
      from 'john@doe.net'
      subject 'gpg test'
      body "encrypt me!"
      add_file "some_attachment.zip"
    end

    # encrypt message, no signing
    Mail::Gpg.encrypt(m).deliver

    # encrypt and sign message with sender's private key, using the given
    # passphrase to decrypt the key
    Mail::Gpg.encrypt(m, sign: true, password: 'secret').deliver

    # encrypt and sign message using a different key
    Mail::Gpg.encrypt(m, sign_as: 'joe@otherdomain.com', password: 'secret').deliver

    # encrypt and sign message and use a callback function to provide the
    # passphrase. See the [GPGME::Ctx](https://github.com/ueno/ruby-gpgme/blob/master/lib/gpgme/ctx.rb) class for more info on the various arguments.
    # Use the :passphrase_callback_value option to give your callback 
    # function some custom context via its first argument.
    Mail::Gpg.encrypt(m, sign_as: 'joe@otherdomain.com',
                         passphrase_callback: ->(obj, uid_hint, passphrase_info, prev_was_bad, fd){puts "Enter passphrase for #{passphrase_info}: "; (IO.for_fd(fd, 'w') << readline.chomp).flush }).deliver

Make sure all recipients' public keys are in your local gpg keychain.


### Signing only

This is not implemented yet


## Todo

* Signing of unencrypted mails
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


