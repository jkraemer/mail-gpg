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

    end
  end
end
