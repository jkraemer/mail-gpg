require 'mail/gpg/verified_part'

module Mail
  module Gpg
    class InlineSignedMessage < Mail::Message

      def self.setup(signed_mail, options = {})
        if signed_mail.multipart?
          self.new do
            global_verify_result = []
            signed_mail.header.fields.each do |field|
              header[field.name] = field.value
            end
            signed_mail.parts.each do |part|
              if Mail::Gpg.signed_inline?(part)
                signed_text = part.body.to_s
                success, vr = GpgmeHelper.inline_verify(signed_text, options)
                p = VerifiedPart.new(part)
                if success
                  p.body self.class.strip_inline_signature signed_text
                end
                p.verify_result vr
                global_verify_result << vr
                add_part p
              else
                add_part part
              end
            end
            verify_result global_verify_result
          end # of multipart
        else
          self.new do
            signed_mail.header.fields.each do |field|
              header[field.name] = field.value
            end
            signed_text = signed_mail.body.to_s
            success, vr = GpgmeHelper.inline_verify(signed_text, options)
            if success
              body self.class.strip_inline_signature signed_text
            else
              body signed_text
            end
            verify_result vr
          end
        end
      end

      END_SIGNED_TEXT = '-----END PGP SIGNED MESSAGE-----'
      END_SIGNED_TEXT_RE = /^#{END_SIGNED_TEXT}\s*$/
      INLINE_SIG_RE = Regexp.new('^-----BEGIN PGP SIGNATURE-----\s*$.*^-----END PGP SIGNATURE-----\s*$', Regexp::MULTILINE)
      BEGIN_SIG_RE = /^(-----BEGIN PGP SIGNATURE-----)\s*$/


      # utility method to remove inline signature and related pgp markers
      def self.strip_inline_signature(signed_text)
        if signed_text =~ INLINE_SIG_RE
          signed_text = signed_text.dup
          if signed_text !~ END_SIGNED_TEXT_RE
            # insert the 'end of signed text' marker in case it is missing
            signed_text = signed_text.gsub BEGIN_SIG_RE, "-----END PGP SIGNED MESSAGE-----\n\\1"
          end
          signed_text.gsub! INLINE_SIG_RE, ''
          signed_text.strip!
        end
        # Strip possible inline-"headers" (e.g. "Hash: SHA256", or "Comment: something").
        signed_text.gsub(/(.*^-----BEGIN PGP SIGNED MESSAGE-----\n)(.*?)^$(.+)/m, '\1\3')
      end

    end
  end
end


