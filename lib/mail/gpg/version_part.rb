require 'mail/part'

module Mail
  module Gpg
    class VersionPart < Mail::Part
      def initialize(*args)
        super
        body 'Version: 1'
        content_type 'application/pgp-encrypted'
        content_description 'PGP/MIME Versions Identification'
      end
    end
  end
end
