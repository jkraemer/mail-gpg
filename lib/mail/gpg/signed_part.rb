require 'mail/part'
require 'mail/gpg/sign_part'

module Mail
  module Gpg

    class SignedPart < Mail::Part

      def self.build(cleartext_mail)
        new do
          if cleartext_mail.multipart?
            if cleartext_mail.content_type =~ /^(multipart[^;]+)/
              # preserve multipart/alternative etc
              content_type $1
            else
              content_type 'multipart/mixed'
            end
            cleartext_mail.body.parts.each do |p|
              add_part Mail::Gpg::SignedPart.build(p)
            end
          else
            content_type cleartext_mail.content_type
            body cleartext_mail.body.raw_source
          end
        end
      end

      def sign(options)
        SignPart.new(self, options)
      end


    end


  end
end
