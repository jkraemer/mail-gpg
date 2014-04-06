require 'test_helper'

# test cases for PGP inline messages (i.e. non-mime)
class InlineDecryptedMessageTest < Test::Unit::TestCase

  context "InlineDecryptedMessage" do

    setup do
      (@mails = Mail::TestMailer.deliveries).clear
      @mail = Mail.new do
        to 'jane@foo.bar'
        from 'joe@foo.bar'
        subject 'test'
        body 'i am unencrypted'
        gpg encrypt: false
      end
    end

    context "inline message" do
      should "decrypt and verify body" do
        mail = Mail.new(@mail)
        mail.body = InlineDecryptedMessageTest.encrypt(mail, mail.body.to_s)

        assert !mail.multipart?
        assert mail.encrypted?
        assert decrypted = mail.decrypt(:password => 'abc', verify: true)
        assert decrypted == @mail
        assert !decrypted.encrypted?
        assert vr = decrypted.verify_result
        assert sig = vr.signatures.first
        assert sig.to_s=~ /Joe/
        assert sig.valid?
      end
    end

    context "attachment message" do
      should "decrypt attachment" do
        rakefile = File.open('Rakefile') { |file| file.read }
        mail = Mail.new(@mail)
        mail.content_type = 'multipart/mixed'
        mail.body = ''
        mail.part do |p|
          p.content_type 'application/octet-stream; name=Rakefile.pgp'
          p.content_transfer_encoding Mail::Encodings::Base64
          p.content_disposition 'attachment; filename="Rakefile.pgp"'
          p.body Mail::Encodings::Base64::encode(InlineDecryptedMessageTest.encrypt(mail, rakefile, false))
        end

        assert mail.multipart?
        assert mail.encrypted?
        assert decrypted = mail.decrypt(:password => 'abc')
        assert !decrypted.encrypted?
        check_headers(@mail, decrypted)
        assert_equal 1, decrypted.parts.length
        assert /application\/octet-stream; (?:charset=UTF-8; )?name=Rakefile/ =~ decrypted.parts[0].content_type
        assert_equal 'attachment; filename=Rakefile', decrypted.parts[0].content_disposition
        assert_equal rakefile, decrypted.parts[0].body.decoded
      end
    end

    context "cleartext body and encrypted attachment message" do
      should "decrypt and verify attachment" do
        rakefile = File.open('Rakefile') { |file| file.read }
        mail = Mail.new(@mail)
        mail.content_type = 'multipart/mixed'
        mail.part do |p|
          p.content_type 'application/octet-stream; name=Rakefile.pgp'
          p.content_transfer_encoding Mail::Encodings::Base64
          p.content_disposition 'attachment; filename="Rakefile.pgp"'
          p.body Mail::Encodings::Base64::encode(InlineDecryptedMessageTest.encrypt(mail, rakefile, false))
        end

        assert mail.multipart?
        assert mail.encrypted?
        assert decrypted = mail.decrypt(password: 'abc', verify: true)
        assert !decrypted.encrypted?
        check_headers(@mail, decrypted)
        assert_equal 2, decrypted.parts.length
        assert_equal @mail.body, decrypted.parts[0].body.to_s
        assert /application\/octet-stream; (?:charset=UTF-8; )?name=Rakefile/ =~ decrypted.parts[1].content_type
        assert_equal 'attachment; filename=Rakefile', decrypted.parts[1].content_disposition
        assert_equal rakefile, decrypted.parts[1].body.decoded

        assert_nil decrypted.parts[0].verify_result
        assert vr = decrypted.parts[1].verify_result
        assert sig = vr.signatures.first
        assert sig.to_s=~ /Joe/
        assert sig.valid?
      end
    end

    context "encrypted body and attachment message" do
      should "decrypt and verify" do
        rakefile = File.open('Rakefile') { |file| file.read }
        mail = Mail.new(@mail)
        mail.content_type = 'multipart/mixed'
        mail.body = InlineDecryptedMessageTest.encrypt(mail, mail.body.to_s)
        mail.part do |p|
          p.content_type 'application/octet-stream; name=Rakefile.pgp'
          p.content_transfer_encoding Mail::Encodings::Base64
          p.content_disposition 'attachment; filename="Rakefile.pgp"'
          p.body Mail::Encodings::Base64::encode(InlineDecryptedMessageTest.encrypt(mail, rakefile, false))
        end

        assert mail.multipart?
        assert mail.encrypted?
        assert decrypted = mail.decrypt(password: 'abc', verify: true)
        assert !decrypted.encrypted?
        check_headers(@mail, decrypted)
        assert_equal 2, decrypted.parts.length
        assert_equal @mail.body, decrypted.parts[0].body.to_s
        assert /application\/octet-stream; (?:charset=UTF-8; )?name=Rakefile/ =~ decrypted.parts[1].content_type
        assert_equal 'attachment; filename=Rakefile', decrypted.parts[1].content_disposition
        assert_equal rakefile, decrypted.parts[1].body.decoded
        decrypted.parts.each do |part|
          assert vr = part.verify_result
          assert sig = vr.signatures.first
          assert sig.to_s=~ /Joe/
          assert sig.valid?
        end
      end
    end
  end

  def self.encrypt(mail, plain, armor = true)
    GPGME::Crypto.new.encrypt(plain,
      password: 'abc',
      recipients: mail.to,
      sign: true,
      signers: mail.from,
      armor: armor).to_s
  end

  def check_headers(expected, actual)
    assert_equal expected.to, actual.to
    assert_equal expected.cc, actual.cc
    assert_equal expected.bcc, actual.bcc
    assert_equal expected.subject, actual.subject
    assert_equal expected.message_id, actual.message_id
    assert_equal expected.date, actual.date
  end
end
