require 'mail/part'

module Mail
  module Gpg
    class VersionPart < Mail::Part
      VERSION_1 = 'Version: 1'
      CONTENT_TYPE = 'application/pgp-encrypted'
      CONTENT_DESC = 'PGP/MIME Versions Identification'
    
      def initialize(*args)
        super
        body VERSION_1
        content_type CONTENT_TYPE
        content_description CONTENT_DESC
      end
      
      def self.isVersionPart?(part)
        part.mime_type == CONTENT_TYPE && part.body =~ /#{VERSION_1}/
      end
    end
  end
end
