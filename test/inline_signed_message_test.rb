require 'test_helper'

# test cases for PGP inline signed messages (i.e. non-mime)
class InlineSignedMessageTest < MailGpgTestCase

  context "InlineSignedMessage" do

    setup do
      (@mails = Mail::TestMailer.deliveries).clear
      @mail = Mail.new do
        to 'jane@foo.bar'
        from 'joe@foo.bar'
        subject 'test'
        body 'i am unencrypted'
      end
    end

    context 'strip_inline_signature' do
      should 'strip signature from signed text' do
        body = self.class.inline_sign(@mail, 'i am signed')
        assert stripped_body = Mail::Gpg::InlineSignedMessage.strip_inline_signature(body)
        assert_equal "-----BEGIN PGP SIGNED MESSAGE-----\n\ni am signed\n-----END PGP SIGNED MESSAGE-----", stripped_body
      end

      should 'not change unsigned text' do
        assert stripped_body = Mail::Gpg::InlineSignedMessage.strip_inline_signature("foo\nbar\n")
        assert_equal "foo\nbar\n", stripped_body
      end
    end

    context "signed message" do
      should "verify body" do
        mail = Mail.new(@mail)
        mail.body = self.class.inline_sign(mail, mail.body.to_s)
        assert !mail.multipart?
        assert mail.signed?
        assert verified = mail.verify
        assert verified.signature_valid?
        assert sig = verified.signatures.first
        assert sig.to_s=~ /Joe/
        assert sig.valid?
      end

      should "detect invalid sig" do
        mail = Mail.new(@mail)
        mail.body = self.class.inline_sign(mail, mail.body.to_s).gsub /i am/, 'i was'
        assert !mail.multipart?
        assert mail.signed?
        assert verified = mail.verify
        assert !verified.signature_valid?
        assert vr = verified.verify_result
        assert sig = verified.signatures.first
        assert sig.to_s=~ /Joe/
        assert !sig.valid?
      end

      should "verify base64 encoded body" do
        mail = Mail.new(@mail)
        signed_text = self.class.inline_sign(mail, mail.body.to_s)
        mail.content_transfer_encoding 'base64'
        mail.body Mail::Encodings::Base64.encode(signed_text)
        mail = Mail.new(mail.encoded)
        assert !mail.multipart?
        assert mail.signed?
        assert verified = mail.verify
        assert verified.signature_valid?
        assert verified.body.decoded.include?('i am unencrypted'),
          "body was double decoded: #{verified.body.decoded.inspect}"
      end

      should "keep base64 encoded body readable when signature is invalid" do
        mail = Mail.new(@mail)
        signed_text = self.class.inline_sign(mail, mail.body.to_s).gsub /i am/, 'i was'
        mail.content_transfer_encoding 'base64'
        mail.body Mail::Encodings::Base64.encode(signed_text)
        mail = Mail.new(mail.encoded)
        assert !mail.multipart?
        assert mail.signed?
        assert verified = mail.verify
        assert !verified.signature_valid?
        assert verified.body.decoded.include?('i was unencrypted'),
          "body was double decoded: #{verified.body.decoded.inspect}"
      end

    end

    context "message with signed attachment" do
      should "check base64 encoded attachment signature" do
        mail = Mail.new(@mail)
        mail.body = 'foobar'
        signed_text = self.class.inline_sign(mail, 'sign me!')
        mail.part do |p|
          p.content_transfer_encoding 'base64'
          p.body Mail::Encodings::Base64.encode(signed_text)
        end
        mail = Mail.new(mail.encoded)
        assert mail.multipart?
        assert mail.signed?
        assert verified = mail.verify
        assert verified.signature_valid?
        assert verified.parts.last.body.decoded.include?('sign me!'),
          "part was double decoded: #{verified.parts.last.body.decoded.inspect}"
      end

      should "check attachment signature" do
        mail = Mail.new(@mail)
        mail.body = 'foobar'
        mail.part do |p|
          p.body = self.class.inline_sign(mail, 'sign me!')
        end
        assert mail.multipart?
        assert mail.signed?
        assert verified = mail.verify
        assert verified.signature_valid?
        assert vr = verified.parts.last.verify_result
        assert !verified.parts.first.signed?
        assert verified.parts.last.signed?
        assert Mail::Gpg.signed_inline?(verified.parts.last)
        assert_equal [vr], verified.verify_result
        assert sig = verified.signatures.first
        assert sig.to_s=~ /Joe/
        assert sig.valid?
      end

      should "detect invalid sig" do
        mail = Mail.new(@mail)
        mail.body = 'foobar'
        mail.part do |p|
          p.body = self.class.inline_sign(mail, 'i am signed!').gsub /i am/, 'i was'
        end
        mail.part do |p|
          p.body = self.class.inline_sign(mail, 'i am signed!')
        end

        assert mail.multipart?
        assert mail.signed?
        assert verified = mail.verify
        assert !verified.signature_valid?
        assert vr = verified.verify_result
        assert_equal 2, vr.size

        invalid = verified.parts[1]
        assert !invalid.signature_valid?
        assert sig = invalid.verify_result.signatures.first
        assert sig.to_s=~ /Joe/
        assert !sig.valid?

        valid = verified.parts[2]
        assert valid.signature_valid?
        assert sig = valid.verify_result.signatures.first
        assert sig.to_s=~ /Joe/
        assert sig.valid?
      end
    end
  end


  def self.inline_sign(mail, plain, armor = true)
    GPGME::Crypto.new.clearsign(plain,
      password: 'abc',
      signers: mail.from,
      armor: armor).to_s
  end

end

