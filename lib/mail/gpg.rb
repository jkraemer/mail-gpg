require 'mail'
require 'mail/message'
require 'gpgme'

require 'mail/gpg/version'
require 'mail/gpg/missing_keys_error'
require 'mail/gpg/version_part'
require 'mail/gpg/decrypted_part'
require 'mail/gpg/encrypted_part'
require 'mail/gpg/inline_decrypted_message'
require 'mail/gpg/gpgme_helper'
require 'mail/gpg/message_patch'
require 'mail/gpg/rails'
require 'mail/gpg/signed_part'
require 'mail/gpg/mime_signed_message'
require 'mail/gpg/inline_signed_message'

module Mail
  module Gpg
    # options are:
    # :sign: sign message using the sender's private key
    # :sign_as: sign using this key (give the corresponding email address or key fingerprint)
    # :passphrase: passphrase for the signing key
    # :keys: A hash mapping recipient email addresses to public keys or public
    # key ids. Imports any keys given here that are not already part of the
    # local keychain before sending the mail.
    # :always_trust: send encrypted mail to untrusted receivers, true by default
    def self.encrypt(cleartext_mail, options = {})
      construct_mail(cleartext_mail, options) do
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

        add_part VersionPart.new
        add_part EncryptedPart.new(cleartext_mail,
                                   options.merge({recipients: receivers}))
        content_type "multipart/encrypted; protocol=\"application/pgp-encrypted\"; boundary=#{boundary}"
        body.preamble = options[:preamble] || "This is an OpenPGP/MIME encrypted message (RFC 2440 and 3156)"
      end
    end

    def self.sign(cleartext_mail, options = {})
      options[:sign_as] ||= cleartext_mail.from
      construct_mail(cleartext_mail, options) do
        to_be_signed = SignedPart.build(cleartext_mail)
        add_part to_be_signed
        add_part to_be_signed.sign(options)

        content_type "multipart/signed; micalg=pgp-sha1; protocol=\"application/pgp-signature\"; boundary=#{boundary}"
        body.preamble = options[:preamble] || "This is an OpenPGP/MIME signed message (RFC 4880 and 3156)"
      end
    end

    # options are:
    # :verify: decrypt and verify
    def self.decrypt(encrypted_mail, options = {})
      if encrypted_mime?(encrypted_mail)
        decrypt_pgp_mime(encrypted_mail, options)
      elsif encrypted_inline?(encrypted_mail)
        decrypt_pgp_inline(encrypted_mail, options)
      else
        raise EncodingError, "Unsupported encryption format '#{encrypted_mail.content_type}'"
      end
    end

    def self.signature_valid?(signed_mail, options = {})
      if signed_mime?(signed_mail)
        signature_valid_pgp_mime?(signed_mail, options)
      elsif signed_inline?(signed_mail)
        signature_valid_inline?(signed_mail, options)
      else
        raise EncodingError, "Unsupported signature format '#{signed_mail.content_type}'"
      end
    end

    # true if a mail is encrypted
    def self.encrypted?(mail)
      return true if encrypted_mime?(mail)
      return true if encrypted_inline?(mail)
      false
    end

    # true if a mail is signed.
    #
    # throws EncodingError if called on an encrypted mail (so only call this method if encrypted? is false)
    def self.signed?(mail)
      return true if signed_mime?(mail)
      return true if signed_inline?(mail)
      if encrypted?(mail)
        raise EncodingError, 'Unable to determine signature on an encrypted mail, use :verify option on decrypt()'
      end
      false
    end

    private

    def self.construct_mail(cleartext_mail, options, &block)
      Mail.new do
        self.perform_deliveries = cleartext_mail.perform_deliveries
        Mail::Gpg.copy_headers cleartext_mail, self
        # necessary?
        if cleartext_mail.message_id
          header['Message-ID'] = cleartext_mail['Message-ID'].value
        end
        instance_eval &block
      end
    end

    # decrypts PGP/MIME (RFC 3156, section 4) encrypted mail
    def self.decrypt_pgp_mime(encrypted_mail, options)
      if encrypted_mail.parts.length < 2
        raise EncodingError, "RFC 3156 mandates exactly two body parts, found '#{encrypted_mail.parts.length}'"
      end
      if !VersionPart.isVersionPart? encrypted_mail.parts[0]
        raise EncodingError, "RFC 3156 first part not a valid version part '#{encrypted_mail.parts[0]}'"
      end
      decrypted = DecryptedPart.new(encrypted_mail.parts[1], options)
      Mail.new(decrypted.raw_source) do
        # headers from the encrypted part (set by the initializer above) take
        # precedence over those from the outer mail.
        Mail::Gpg.copy_headers encrypted_mail, self, overwrite: false
        verify_result decrypted.verify_result if options[:verify]
      end
    end

    # decrypts inline PGP encrypted mail
    def self.decrypt_pgp_inline(encrypted_mail, options)
      InlineDecryptedMessage.setup(encrypted_mail, options)
    end

    def self.verify(signed_mail, options = {})
      if signed_mime?(signed_mail)
        Mail::Gpg::MimeSignedMessage.setup signed_mail, options
      elsif signed_inline?(signed_mail)
        Mail::Gpg::InlineSignedMessage.setup signed_mail, options
      else
        signed_mail
      end
    end

    # check signature for PGP/MIME (RFC 3156, section 5) signed mail
    def self.signature_valid_pgp_mime?(signed_mail, options)
      # MUST contain exactly two body parts
      if signed_mail.parts.length != 2
        raise EncodingError, "RFC 3156 mandates exactly two body parts, found '#{signed_mail.parts.length}'"
      end
      result, verify_result = SignPart.verify_signature(signed_mail.parts[0], signed_mail.parts[1], options)
      signed_mail.verify_result = verify_result
      return result
    end

    # check signature for inline signed mail
    def self.signature_valid_inline?(signed_mail, options)
      result = nil
      if signed_mail.multipart?
        signed_mail.parts.each do |part|
          if signed_inline?(part)
            if result.nil?
              result = true
              signed_mail.verify_result = []
            end
            result &= signature_valid_inline?(part, options)
            signed_mail.verify_result << part.verify_result
          end
        end
      else
        result, verify_result = GpgmeHelper.inline_verify(signed_mail.body.to_s, options)
        signed_mail.verify_result = verify_result
      end
      return result
    end

    # copies all header fields from mail in first argument to that given last
    def self.copy_headers(from, to, overwrite: true)
      from.header.fields.each do |field|
        if overwrite || to.header[field.name].nil?
          to.header[field.name] = field.value
        end
      end
    end


    # check if PGP/MIME encrypted (RFC 3156)
    def self.encrypted_mime?(mail)
      mail.has_content_type? &&
        'multipart/encrypted' == mail.mime_type &&
        'application/pgp-encrypted' == mail.content_type_parameters[:protocol]
    end

    # check if inline PGP (i.e. if any parts of the mail includes
    # the PGP MESSAGE marker)
    def self.encrypted_inline?(mail)
      return true if mail.body.include?('-----BEGIN PGP MESSAGE-----')
      if mail.multipart?
        mail.parts.each do |part|
          return true if part.body.include?('-----BEGIN PGP MESSAGE-----')
          return true if part.has_content_type? &&
            /application\/(?:octet-stream|pgp-encrypted)/ =~ part.mime_type &&
            /.*\.(?:pgp|gpg|asc)$/ =~ part.content_type_parameters[:name] &&
            'signature.asc' != part.content_type_parameters[:name]
          # that last condition above prevents false positives in case e.g.
          # someone forwards a mime signed mail including signature.
        end
      end
      false
    end

    # check if PGP/MIME signed (RFC 3156)
    def self.signed_mime?(mail)
      mail.has_content_type? &&
        'multipart/signed' == mail.mime_type &&
        'application/pgp-signature' == mail.content_type_parameters[:protocol]
    end

    # check if inline PGP (i.e. if any parts of the mail includes
    # the PGP SIGNED marker)
    def self.signed_inline?(mail)
      return true if mail.body.to_s =~ /^-----BEGIN PGP SIGNED MESSAGE-----/
      if mail.multipart?
        mail.parts.each do |part|
          return true if part.body.to_s =~ /^-----BEGIN PGP SIGNED MESSAGE-----/
        end
      end
      false
    end
  end
end
