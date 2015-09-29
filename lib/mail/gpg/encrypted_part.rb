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
      # :filename : define a custom name for the encrypted file attachment
      def initialize(cleartext_mail, options = {})
        options = { always_trust: true }.merge options

        encrypted = GpgmeHelper.encrypt(cleartext_mail.encoded, options)
        super() do
          body encrypted.to_s
          filename = options[:filename] || 'encrypted.asc'
          content_type "#{CONTENT_TYPE}; name=\"#{filename}\""
          content_disposition 'inline; filename="#{filename}"'
          content_description 'OpenPGP encrypted message'
        end
      end
    end
  end
end
