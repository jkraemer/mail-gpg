module Mail
  module Gpg
    class EncryptedPart < Mail::Part

      # options are:
      # :recipients : array of receiver addresses
      # :always_trust : send encrypted mail to untrusted receivers, true by default
      def initialize(parts, options = {})
        options = { always_trust: true }.merge options
        clear_part = Mail.new
        parts.each do |p|
          clear_part.add_part p
        end

        c = GPGME::Crypto.new
        enc = c.encrypt(clear_part.encoded, options.merge({armor: true})).to_s

        super do
          body enc
          content_type 'application/octet-stream; name="encrypted.asc"'
          content_disposition 'inline; filename="encrypted.asc"'
          content_description 'OpenPGP encrypted message'
        end
      end

    end
  end
end
