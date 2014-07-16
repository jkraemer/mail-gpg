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

    STANDARD_HEADERS = %w(from to cc bcc reply_to subject in_reply_to return_path message_id)
    MORE_HEADERS = %w(Auto-Submitted References)

    private

    def self.construct_mail(cleartext_mail, options, &block)
      Mail.new do
        self.perform_deliveries = cleartext_mail.perform_deliveries
        STANDARD_HEADERS.each do |field|
          if h = cleartext_mail.header[field]
            self.header[field] = h.value
          end
        end
        cleartext_mail.header.fields.each do |field|
          if MORE_HEADERS.include?(field.name) or field.name =~ /^X-/
            header[field.name] = field.value
          end
        end
        instance_eval &block
      end
    end

    # decrypts PGP/MIME (RFC 3156, section 4) encrypted mail
    def self.decrypt_pgp_mime(encrypted_mail, options)
      # MUST containt exactly two body parts
      if encrypted_mail.parts.length != 2
        raise EncodingError, "RFC 3136 mandates exactly two body parts, found '#{encrypted_mail.parts.length}'"
      end
      if !VersionPart.isVersionPart? encrypted_mail.parts[0]
        raise EncodingError, "RFC 3136 first part not a valid version part '#{encrypted_mail.parts[0]}'"
      end
      decrypted = DecryptedPart.new(encrypted_mail.parts[1], options)
      Mail.new(decrypted) do
        %w(from to cc bcc subject reply_to in_reply_to).each do |field|
          send field, encrypted_mail.send(field)
        end
        # copy header fields
        # headers from the encrypted part (which are already set by Mail.new
        # above) will be preserved.
        encrypted_mail.header.fields.each do |field|
          header[field.name] = field.value if field.name =~ /^X-/ && header[field.name].nil?
        end
        verify_result decrypted.verify_result if options[:verify]
      end
    end

    # decrypts inline PGP encrypted mail
    def self.decrypt_pgp_inline(encrypted_mail, options)
      InlineDecryptedMessage.new(encrypted_mail, options)
    end

    # check signature for PGP/MIME (RFC 3156, section 5) signed mail
    def self.signature_valid_pgp_mime?(signed_mail, options)
      # MUST contain exactly two body parts
      if signed_mail.parts.length != 2
        raise EncodingError, "RFC 3136 mandates exactly two body parts, found '#{signed_mail.parts.length}'"
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

    INLINE_SIGNED_MARKER_RE = Regexp.new('^-----(BEGIN|END) PGP SIGNED MESSAGE-----$(\s*Hash: \w+$)?', Regexp::MULTILINE)
    INLINE_SIG_RE = Regexp.new('-----BEGIN PGP SIGNATURE-----.*-----END PGP SIGNATURE-----', Regexp::MULTILINE)
    # utility method to remove inline signature and related pgp markers
    def self.strip_inline_signature(signed_text)
      signed_text.gsub(INLINE_SIGNED_MARKER_RE, '').gsub(INLINE_SIG_RE, '').strip
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
            /.*\.(?:pgp|gpg|asc)$/ =~ part.content_type_parameters[:name]
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
      return true if mail.body.include?('-----BEGIN PGP SIGNED MESSAGE-----')
      if mail.multipart?
        mail.parts.each do |part|
          return true if part.body.include?('-----BEGIN PGP SIGNED MESSAGE-----')
        end
      end
      false
    end
  end
end
