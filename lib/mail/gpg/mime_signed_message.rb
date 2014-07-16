require 'mail/gpg/verified_part'

module Mail
  module Gpg
    class MimeSignedMessage < Mail::Message

      def initialize(signed_mail, options = {})
        content_part, signature = signed_mail.parts
        success, vr = SignPart.verify_signature(content_part, signature, options)
        super() do
          verify_result vr
          signed_mail.header.fields.each do |field|
            header[field.name] = field.value
          end
          content_part.header.fields.each do |field|
            header[field.name] = field.value
          end
          if content_part.multipart?
            content_part.parts.each{|part| add_part part}
          else
            body content_part.body.to_s
          end
        end
      end
    end
  end
end



