require 'mail'
require 'mail/message'
require 'gpgme'

require 'mail/gpg/version'
require 'mail/gpg/version_part'
require 'mail/gpg/decrypted_part'
require 'mail/gpg/encrypted_part'
require 'mail/gpg/message_patch'
require 'mail/gpg/rails'
require 'mail/gpg/sign_part'

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
			construct_mail(cleartext_mail, options) do
				options[:sign_as] ||= cleartext_mail.from
				add_part SignPart.new(cleartext_mail, options)
				add_part Mail::Part.new(cleartext_mail)	

				content_type "multipart/signed; micalg=pgp-sha1; protocol=\"application/pgp-signature\"; boundary=#{boundary}"
				body.preamble = options[:preamble] || "This is an OpenPGP/MIME signed message (RFC 4880 and 3156)"
			end	
		end

    def self.decrypt(encrypted_mail, options = {})
      if (encrypted_mail.has_content_type? && 
          'multipart/encrypted' == encrypted_mail.mime_type &&
          'application/pgp-encrypted' == encrypted_mail.content_type_parameters[:protocol])
         
         decrypt_pgp_mime(encrypted_mail, options)
      else
        raise EncodingError, "Unsupported encryption format '#{encrypted_mail.content_type}'"
      end
    end
    
    private

		def self.construct_mail(cleartext_mail, options, &block)	
      Mail.new do
        self.perform_deliveries = cleartext_mail.perform_deliveries
        %w(from to cc bcc subject reply_to in_reply_to).each do |field|
          send field, cleartext_mail.send(field)
        end
        cleartext_mail.header.fields.each do |field|
          header[field.name] = field.value if field.name =~ /^X-/
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
      Mail.new(DecryptedPart.new(encrypted_mail.parts[1], options))
    end
  end
end
