module Mail
  module Gpg
    class SignPart < Mail::Part

      def initialize(cleartext_mail, options = {})
        signature = GpgmeHelper.sign(cleartext_mail.encoded, options)
        super() do
          body signature.to_s
          content_type "application/pgp-signature; name=\"signature.asc\""
          content_disposition 'attachment; filename="signature.asc"'
          content_description 'OpenPGP digital signature'
        end
      end

      # true if all signatures are valid
      def self.signature_valid?(plain_part, signature_part, options = {})
        verify_signature(plain_part, signature_part, options)[0]
      end

      # will return [success(boolean), verify_result(as returned by gpgme)]
      def self.verify_signature(plain_part, signature_part, options = {})
        if !(signature_part.has_content_type? &&
             ('application/pgp-signature' == signature_part.mime_type))
          return false
        end

        signature = signature_part.body.encoded
        GpgmeHelper.sign_verify(plain_part.encoded, signature, options)
      end
    end
  end
end
