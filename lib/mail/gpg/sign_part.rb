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

      def self.signature_valid?(plain_part, signature_part, options = {})
        if !(signature_part.has_content_type? &&
             ('application/pgp-signature' == signature_part.mime_type))
          return false
        end

        # Work around the problem that plain_part.raw_source prefixes an
        # erronous CRLF, <https://github.com/mikel/mail/issues/702>.
        plaintext = [
                      plain_part.header.raw_source,
                      "\r\n\r\n",
                      plain_part.body.raw_source
                    ].join
        signature = signature_part.body.encoded
        GpgmeHelper.sign_verify(plaintext, signature, options)
      end
    end
  end
end
