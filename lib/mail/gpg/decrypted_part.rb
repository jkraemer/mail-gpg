module Mail
  module Gpg
    class DecryptedPart < Mail::Part

      # options are:
      #
      # :verify: decrypt and verify
      def initialize(cipher_part, options = {})
        if cipher_part.mime_type != EncryptedPart::CONTENT_TYPE
          raise EncodingError, "RFC 3156 incorrect mime type for encrypted part '#{cipher_part.mime_type}'"
        end

        decrypted = GpgmeHelper.decrypt(cipher_part.body.decoded, options)
        super(decrypted)
      end
    end
  end
end
