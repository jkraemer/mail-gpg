module Mail
  module Gpg
    class EncryptedPart < Mail::Part

      CONTENT_TYPE = 'application/octet-stream'

      # options are:
      #
      # :signers : sign using this key (give the corresponding email address)
      # :password: passphrase for the signing key
      # :recipients : array of receiver addresses
      # :keys : A hash mapping recipient email addresses to public keys or public
      # key ids. Imports any keys given here that are not already part of the
      # local keychain before sending the mail.
      # :always_trust : send encrypted mail to untrusted receivers, true by default
      def initialize(cleartext_mail, options = {})
        options = { always_trust: true }.merge options

        encrypted = encrypt(cleartext_mail.encoded, options)
        super() do
          body encrypted.to_s
          content_type "#{CONTENT_TYPE}; name=\"encrypted.asc\""
          content_disposition 'inline; filename="encrypted.asc"'
          content_description 'OpenPGP encrypted message'
        end
      end

      private

      def encrypt(plain, options = {})
        options = options.merge({armor: true})

        plain_data  = GPGME::Data.new(plain)
        cipher_data = GPGME::Data.new(options[:output])

        recipient_keys = keys_for_data options[:recipients], options.delete(:keys), options

        flags = 0
        flags |= GPGME::ENCRYPT_ALWAYS_TRUST if options[:always_trust]

        GPGME::Ctx.new(options) do |ctx|
          begin
            if options[:sign]
              if options[:signers]
                signers = GPGME::Key.find(:public, options[:signers], :sign)
                ctx.add_signer(*signers)
              end
              ctx.encrypt_sign(recipient_keys, plain_data, cipher_data, flags)
            else
              ctx.encrypt(recipient_keys, plain_data, cipher_data, flags)
            end
          rescue GPGME::Error::UnusablePublicKey => exc
            exc.keys = ctx.encrypt_result.invalid_recipients
            raise exc
          rescue GPGME::Error::UnusableSecretKey => exc
            exc.keys = ctx.sign_result.invalid_signers
            raise exc
          end
        end

        cipher_data.seek(0)
        cipher_data
      end

      # normalizes the list of recipients' emails, key ids and key data to a
      # list of Key objects
      def keys_for_data(emails_or_shas_or_keys, key_data = nil, options = {})
        if key_data
          [emails_or_shas_or_keys].flatten.map do |r|
            # import any given keys
            k = key_data[r]
            if k and k =~ /-----BEGIN PGP/
              k = GPGME::Key.import(k).imports.map(&:fpr)
            end
            k = GPGME::Key.find(:public, k || r, :encrypt)
          end.flatten
        else
					# key lookup in keychain for all receivers
					[emails_or_shas_or_keys].flatten.map do |r|
						keys = GPGME::Key.find(:public, r, :encrypt)
					end.flatten
        end
      end

    end
  end
end
