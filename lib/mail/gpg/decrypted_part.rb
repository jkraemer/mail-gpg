module Mail
  module Gpg
    class DecryptedPart < Mail::Part

      # options are:
      #
      # :verify: decrypt and verify
      def initialize(cipher_part, options = {})
        if cipher_part.mime_type != EncryptedPart::CONTENT_TYPE
          raise EncodingError, "RFC 3136 incorrect mime type for encrypted part '#{cipher_part.mime_type}'"
        end
      
        decrypted = decrypt(cipher_part.body.encoded, options)
        super(decrypted)
      end

      private

      def decrypt(cipher, options = {})
        cipher_data = GPGME::Data.new(cipher)
        plain_data  = GPGME::Data.new(options[:output])

        GPGME::Ctx.new(options) do |ctx|
          begin
            if options[:verify]
              ctx.decrypt_verify(cipher_data, plain_data)
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
    end
  end
end
