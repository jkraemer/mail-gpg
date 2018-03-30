require 'mail/gpg/gpgme_ext'

# GPGME methods for encryption/decryption/signing
module Mail
  module Gpg
    class GpgmeHelper

      def self.encrypt(plain, options = {})
        options = options.merge({armor: true})

        plain_data  = GPGME::Data.new(plain)
        cipher_data = GPGME::Data.new(options[:output])

        recipient_keys = keys_for_data options[:recipients], options.delete(:keys)

        if recipient_keys.empty?
          raise MissingKeysError.new('No keys to encrypt to!')
        end

        flags = 0
        flags |= GPGME::ENCRYPT_ALWAYS_TRUST if options[:always_trust]

        GPGME::Ctx.new(options) do |ctx|
          begin
            if options[:sign]
              if options[:signers] && options[:signers].size > 0
                signers = GPGME::Key.find(:secret, options[:signers], :sign)
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

      def self.decrypt(cipher, options = {})
        cipher_data = GPGME::Data.new(cipher)
        plain_data  = GPGME::Data.new(options[:output])

        GPGME::Ctx.new(options) do |ctx|
          begin
            if options[:verify]
              ctx.decrypt_verify(cipher_data, plain_data)
              plain_data.verify_result = ctx.verify_result
            else
              ctx.decrypt(cipher_data, plain_data)
            end
          rescue GPGME::Error::UnsupportedAlgorithm => exc
            exc.algorithm = ctx.decrypt_result.unsupported_algorithm
            raise exc
          rescue GPGME::Error::WrongKeyUsage => exc
            exc.key_usage = ctx.decrypt_result.wrong_key_usage
            raise exc
          end
        end

        plain_data.seek(0)
        plain_data
      end

      def self.sign(plain, options = {})
        options.merge!({
          armor: true,
          signer: options.delete(:sign_as),
          mode: GPGME::SIG_MODE_DETACH
        })
        crypto = GPGME::Crypto.new
        crypto.sign GPGME::Data.new(plain), options
      end

      # returns [success(bool), VerifyResult(from gpgme)]
      # success will be true when there is at least one sig and no invalid sig
      def self.sign_verify(plain, signature, options = {})
        signed_data = GPGME::Data.new(plain)
        signature = GPGME::Data.new(signature)

        success = verify_result = nil
        GPGME::Ctx.new(options) do |ctx|
          ctx.verify signature, signed_data, nil
          verify_result = ctx.verify_result
          signatures = verify_result.signatures
          success = signatures &&
            signatures.size > 0 &&
            signatures.detect{|s| !s.valid? }.nil?
        end
        return [success, verify_result]
      end

      def self.inline_verify(signed_text, options = {})
        signed_data = GPGME::Data.new(signed_text)
        success = verify_result = nil
        GPGME::Ctx.new(options) do |ctx|
          ctx.verify signed_data, nil
          verify_result = ctx.verify_result
          signatures = verify_result.signatures
          success = signatures &&
            signatures.size > 0 &&
            signatures.detect{|s| !s.valid? }.nil?
        end
        return [success, verify_result]
      end

      private

      # normalizes the list of recipients' emails, key ids and key data to a
      # list of Key objects
      def self.keys_for_data(emails_or_shas_or_keys, key_data = nil)
        if key_data
          [emails_or_shas_or_keys].flatten.map do |r|
            # import any given keys
            k = key_data[r]
            if k and k =~ /-----BEGIN PGP/
              k = GPGME::Key.import(k).imports.map(&:fpr)
              k = nil if k.size == 0
            end
            key_id = k || r
            unless key_id.nil? || key_id.empty?
              GPGME::Key.find(:public, key_id, :encrypt)
            end
          end.flatten.compact
        elsif emails_or_shas_or_keys.size > 0
          # key lookup in keychain for all receivers
          GPGME::Key.find :public, emails_or_shas_or_keys, :encrypt
        else
          # empty array given
          []
        end
      end
    end
  end
end
