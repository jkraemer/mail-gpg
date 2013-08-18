require 'mail'
require 'gpgme'

require 'mail/gpg/version'
require 'mail/gpg/version_part'
require 'mail/gpg/encrypted_part'

module Mail
  module Gpg
    # options are:
    # :always_trust : send encrypted mail to untrusted receivers, true by default
    def self.encrypt(cleartext_mail, options = {})
      receivers = []
      receivers += cleartext_mail.to if cleartext_mail.to
      receivers += cleartext_mail.cc if cleartext_mail.cc
      receivers += cleartext_mail.bcc if cleartext_mail.bcc

      Mail.new do
        from cleartext_mail.from
        to cleartext_mail.to
        cc cleartext_mail.cc
        bcc cleartext_mail.bcc
        subject cleartext_mail.subject
        add_part VersionPart.new
        add_part EncryptedPart.new(cleartext_mail.parts,
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
