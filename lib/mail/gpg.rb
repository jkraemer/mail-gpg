require 'mail'
require 'mail/message'
require 'gpgme'

require 'mail/gpg/version'
require 'mail/gpg/version_part'
require 'mail/gpg/encrypted_part'
require 'mail/gpg/message_patch'
require 'mail/gpg/rails'

module Mail
  module Gpg
    # options are:
    # :sign : sign message using the sender's private key
    # :sign_as : sign using this key (give the corresponding email address)
    # :passphrase: passphrase for the signing key
    # :keys : A hash mapping recipient email addresses to public keys or public
    # key ids. Imports any keys given here that are not already part of the
    # local keychain before sending the mail.
    # :always_trust : send encrypted mail to untrusted receivers, true by default
    def self.encrypt(cleartext_mail, options = {})
      receivers = []
      receivers += cleartext_mail.to if cleartext_mail.to
      receivers += cleartext_mail.cc if cleartext_mail.cc
      receivers += cleartext_mail.bcc if cleartext_mail.bcc

      if options[:sign_as]
        options[:sign] = true
        options[:signers] = options.delete(:sign_as)
      elsif options[:sign]
        options[:signers] = cleartext_mail.from
      end

      Mail.new do
        self.perform_deliveries = cleartext_mail.perform_deliveries
        %w(from to cc bcc subject reply_to in_reply_to).each do |field|
          send field, cleartext_mail.send(field)
        end
        cleartext_mail.header.fields.each do |field|
          header[field.name] = field.value if field.name =~ /^X-/
        end
        add_part VersionPart.new
        add_part EncryptedPart.new(cleartext_mail,
                                   options.merge({recipients: receivers}))
        content_type "multipart/encrypted; protocol=\"application/pgp-encrypted\"; boundary=#{boundary}"
        body.preamble = "This is an OpenPGP/MIME encrypted message (RFC 2440 and 3156)"
      end
    end

    def self.decrypt(encrypted_mail, options = {})
      # TODO :)
    end
  end
end
