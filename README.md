# Mail::Gpg [![Build Status](https://travis-ci.org/jkraemer/mail-gpg.png?branch=master)](https://travis-ci.org/jkraemer/mail-gpg)

This gem adds GPG/MIME encryption capabilities to the [Ruby Mail
Library](https://github.com/mikel/mail)

## Installation

Add this line to your application's Gemfile:

    gem 'mail-gpg'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mail-gpg


## Usage

### Encrypting / Signing
Construct your Mail object as usual and specify you want it to be encrypted
with the gpg method:

    Mail.new do
      to 'jane@doe.net'
      from 'john@doe.net'
      subject 'gpg test'
      body "encrypt me!"
      add_file "some_attachment.zip"

      # encrypt message, no signing
      gpg true

      # encrypt and sign message with sender's private key, using the given
      # passphrase to decrypt the key
      gpg sign: true, password: 'secret'

      # encrypt and sign message using a different key
      gpg sign_as: 'joe@otherdomain.com', password: 'secret'


      # encrypt and sign message and use a callback function to provide the
      # passphrase.
      gpg sign_as: 'joe@otherdomain.com',
          passphrase_callback: ->(obj, uid_hint, passphrase_info, prev_was_bad, fd){puts "Enter passphrase for #{passphrase_info}: "; (IO.for_fd(fd, 'w') << readline.chomp).flush }
    end.deliver


Make sure all recipients' public keys are present in your local gpg keychain.
You will get errors in case encryption is not possible due to missing keys.
If you collect public key data from your users, you can specify the ascii
armored key data for recipients using the `:keys` option like this:

    johns_key = <<-END
    -----BEGIN PGP PUBLIC KEY BLOCK-----
    Version: GnuPG v1.4.12 (GNU/Linux)

    mQGiBEk39msRBADw1ExmrLD1OUMdfvA7cnVVYTC7CyqfNvHUVuuBDhV7azs
    ....
    END

    Mail.new do
      to 'john@foo.bar'
      gpg keys: { 'john@foo.bar' => johns_key }
    end

The key will then be imported before actually trying to encrypt/send the mail.
SoiIn theory you only need to specify the key once like that, however doing it
every time does not hurt as gpg is clever enough to recognize known keys, only
updating it's db when necessary.

You may also want to have a look at the [GPGME](https://github.com/ueno/ruby-gpgme) docs and code base for more info on the various options, especially regarding the `passphrase_callback` arguments.


### Signing only

This is not implemented yet


## Rails / ActionMailer integration

    class MyMailer < ActionMailer::Base
      default from: 'baz@bar.com'
      def some_mail
        mail to: 'foo@bar.com', subject: 'subject!', gpg: true
      end
    end

The gpg option takes the same arguments as outlined above for the
Mail::Message#gpg method.

## Running the tests

    bundle exec rake

The first run will take a while since it sets up a mock gpg home directory in
`test/gpghome` containing two different identities used in the test cases.
Following test runs will use that directory if it still exists and will
therefore be substantially faster.

## Todo

* Signing of unencrypted mails
* Decryption
* Signature verification
* Add optional on the fly import of recipients' keys from public key servers based on email address
* Send encrypted mails to recipients when possible, fall back to unencrypted
  mail otherwise


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


