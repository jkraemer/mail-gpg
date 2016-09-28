require 'test_helper'

class GpgTest < Test::Unit::TestCase

  def check_headers(mail = @mail, encrypted = @encrypted)
    assert_equal mail.to, encrypted.to
    assert_equal mail.cc, encrypted.cc
    assert_equal mail.bcc, encrypted.bcc
    assert_equal mail.subject, encrypted.subject
  end

  def check_mime_structure(mail = @mail, encrypted = @encrypted)
    assert_equal 2, encrypted.parts.size
    v_part, enc_part = encrypted.parts

    assert_match /Version: 1/, v_part.to_s
    assert_match /application\/pgp-encrypted(?:; charset=UTF-8)?/, v_part.content_type

    assert_equal 'application/octet-stream; name=encrypted.asc',
    enc_part.content_type
  end

  def check_attachment_name(mail = @mail, encrypted = @encrypted)
    v_part, enc_part = encrypted.parts
    assert_equal 'application/octet-stream; name=custom_filename.asc', enc_part.content_type
    assert_equal 'inline; filename=custom_filename.asc', enc_part.content_disposition
  end

  def check_content(mail = @mail, encrypted = @encrypted)
    assert enc = encrypted.parts.last
    assert clear = GPGME::Crypto.new.decrypt(enc.to_s, password: 'abc').to_s
    assert_match /encrypt me/, clear
    assert_equal mail.to_s, clear
  end

  def check_signature(mail = @mail, signed = @signed)
    assert signed.signed?
    assert signature = signed.parts.detect{|p| p.content_type =~ /signature\.asc/}.body.to_s
    assert signed_part = signed.parts.detect{|p| p.content_type !~ /signature\.asc/}
    assert_equal mail.parts.size, signed_part.parts.size
    GPGME::Crypto.new.verify(signature, signed_text: signed_part.encoded) do |sig|
      assert sig.valid?
    end
    assert Mail::Gpg.signature_valid?(signed)
    assert verified = signed.verify
    assert verified.verify_result.present?
    assert verified.verify_result.signatures.any?
    assert verified.signatures.any?
    assert verified.signature_valid?
  end

  def check_mime_structure_signed(mail = @mail, signed = @signed)
    assert_match /multipart\/signed/, signed.content_type
    assert_equal 2, signed.parts.size
    orig_part, sign_part = signed.parts

    assert_equal 'application/pgp-signature; name=signature.asc', sign_part.content_type
    assert_equal mail.parts.size, orig_part.parts.size
    assert_nil orig_part.to
    assert_nil orig_part.from
    assert_nil orig_part.subject
  end

  def check_headers_signed(mail = @mail, signed = @signed)
    assert_equal mail.to, signed.to
    if mail.cc
      assert_equal mail.cc, signed.cc
    end
    if mail.bcc
      assert_equal mail.bcc, signed.bcc
    end

    assert_equal mail.subject, signed.subject
    assert_equal mail.return_path, signed.return_path
  end

  context "gpg installation" do
    should "have keys for jane and joe" do
      assert joe = GPGME::Key.find(:public, 'joe@foo.bar')
      assert_equal 1, joe.size
      joe = joe.first
      assert jane = GPGME::Key.find(:public, 'jane@foo.bar')
      assert_equal 1, jane.size
      jane = jane.first
      assert id = jane.fingerprint
      assert jane = GPGME::Key.find(:public, id).first
      assert_equal id, jane.fingerprint
    end
  end

  context "gpg signed" do
    setup do
      @mail = Mail.new do
        to 'joe@foo.bar'
        from '<Jane Doe> jane@foo.bar'
        subject 'test test'
        body 'sign me!'
        content_type 'text/plain; charset=UTF-8'
      end
    end

    context 'simple mail' do
      setup do
        @signed = Mail::Gpg.sign(@mail, password: 'abc')
      end

      should 'preserve from name' do
        assert_equal '<Jane Doe> jane@foo.bar', @signed.header['from'].value
      end

      should 'have same recipients and subject' do
        check_headers_signed
      end

      should 'have proper gpgmime structure' do
        check_mime_structure_signed
      end

      should 'have correct signature' do
        check_signature
      end
    end

    context 'mail with custom headers' do
      setup do
        @mail.header['X-Custom-Header'] = 'custom value'
        @mail.header['Return-Path'] = 'bounces@example.com'
        @mail.header['References'] = 'some-message-id'
        @signed = Mail::Gpg.sign(@mail, password: 'abc')
      end

      should 'have same recipients and subject' do
        check_headers_signed
      end

      should 'have proper gpgmime structure' do
        check_mime_structure_signed
      end

      should 'have correct signature' do
        check_signature
      end

      should 'preserve customer header values' do
        assert_equal 'custom value', @signed.header['X-Custom-Header'].to_s
        assert_equal 'bounces@example.com', @signed.return_path
        assert_equal 'some-message-id', @signed.header['References'].value
      end
    end

    context 'mail with multiple recipients' do
      setup do
        @mail.bcc 'jane@foo.bar'
        @signed = Mail::Gpg.sign(@mail, password: 'abc')
      end

      should 'have same recipients and subject' do
        check_headers_signed
      end

      should 'have proper gpgmime structure' do
        check_mime_structure_signed
      end

      should 'have correct signature' do
        check_signature
      end
    end

    context 'multipart alternative mail' do
      setup do
        @mail = Mail.new do
          to 'joe@foo.bar'
          from 'jane@foo.bar'
          subject 'test test'
          text_part do
            body 'sign me!'
          end
          html_part do
            body '<h1>H1</h1>'
          end
        end
        @signed = Mail::Gpg.sign(@mail, password: 'abc')
      end

      should 'have same recipients and subject' do
        check_headers_signed
      end

      should 'have proper gpgmime structure' do
        check_mime_structure_signed
      end

      should 'have correct signature' do
        check_signature
      end

      should 'have multiple parts in original content' do
        assert original_part = @signed.parts.first
        assert @mail.multipart?
        assert_match /alternative/, @mail.content_type
        assert_match /alternative/, original_part.content_type
        assert_equal original_part.parts.size, @mail.parts.size
        assert_match /sign me!/, original_part.parts.first.body.to_s
        assert_match /H1/, original_part.parts.last.body.to_s
      end
    end
  end

  context "gpg encrypted" do

    setup do
      @mail = Mail.new do
        to 'jane@foo.bar'
        from 'joe@foo.bar'
        subject 'test test'
        body 'encrypt me!'
      end
    end

    context 'simple mail' do
      setup do
        @encrypted = Mail::Gpg.encrypt(@mail)
      end

      should 'have same recipients and subject' do
        check_headers
      end

      should 'have proper gpgmime structure' do
        check_mime_structure
      end

      should 'have correctly encrypted content' do
        check_content
      end

      should 'decrypt' do
        assert mail = Mail::Gpg.decrypt(@encrypted, { :password => 'abc' })
        assert mail == @mail
      end
    end

    context 'simple mail (custom filename)' do
      setup do
        @encrypted = Mail::Gpg.encrypt(@mail, {filename: 'custom_filename.asc'})
      end

      should 'have same custom attachment filename' do
        check_attachment_name
      end
    end

    context 'simple mail (signed)' do
      setup do
        @encrypted = Mail::Gpg.encrypt(@mail, { :sign => true, :password => 'abc' })
      end

      should 'have same recipients and subject' do
        check_headers
      end

      should 'have proper gpgmime structure' do
        check_mime_structure
      end

      should 'have correctly encrypted content' do
        check_content
      end

      should 'decrypt and verify' do
        assert mail = Mail::Gpg.decrypt(@encrypted, { :verify => true, :password => 'abc' })
        assert mail == @mail
        assert mail.verify_result
        assert sig = mail.signatures.first
        assert sig.to_s =~ /Joe/
        assert sig.valid?
      end
    end

    context 'mail with custom header' do
      setup do
        @mail.header['X-Custom-Header'] = 'custom value'
        @mail.header['Return-Path'] = 'bounces@example.com'
        @encrypted = Mail::Gpg.encrypt(@mail)
        @encrypted.header['X-Another-Header'] = 'another value'
      end

      should 'have same recipients and subject' do
        check_headers
      end

      should 'have proper gpgmime structure' do
        check_mime_structure
      end

      should 'have correctly encrypted content' do
        check_content
      end

      should 'preserve customer header values' do
        assert_equal 'custom value', @encrypted.header['X-Custom-Header'].to_s
        assert_equal 'bounces@example.com', @encrypted.return_path
      end

      context 'when decrypted' do
        setup do
          @decrypted_mail = Mail::Gpg.decrypt(@encrypted, { :password => 'abc' })
        end

        should 'have same subject and body as the original' do
          assert_equal @mail.subject, @decrypted_mail.subject
          assert_equal @mail.body.to_s, @decrypted_mail.body.to_s
        end

        should 'preserve custom header from encrypted inner mail' do
          assert_equal 'custom value', @decrypted_mail.header['X-Custom-Header'].to_s
        end

        should 'preserve custom header from outer mail' do
          assert_equal 'another value', @decrypted_mail.header['X-Another-Header'].to_s
        end
      end

    end

    context 'mail with multiple recipients' do
      setup do
        @mail.bcc 'joe@foo.bar'
        @encrypted = Mail::Gpg.encrypt(@mail)
      end

      should 'have same recipients and subject' do
        check_headers
      end

      should 'have proper gpgmime structure' do
        check_mime_structure
      end

      should 'have correctly encrypted content' do
        check_content
      end

      should "encrypt for all recipients" do
        assert encrypted_body = @encrypted.parts.last.to_s
      end

      should 'decrypt' do
        assert mail = Mail::Gpg.decrypt(@encrypted, { :password => 'abc' })
        assert mail == @mail
      end
    end

    context 'multipart mail' do
      setup do
        @mail.add_file 'Rakefile'
        @encrypted = Mail::Gpg.encrypt(@mail, sign: true, password: 'abc')
      end

      should 'have same recipients and subject' do
        check_headers
      end

      should 'have proper gpgmime structure' do
        check_mime_structure
      end

      should 'have correctly encrypted content' do
        check_content
      end

      should 'have multiple parts in encrypted content' do
        assert encrypted_body = @encrypted.parts.last.to_s
        assert clear = GPGME::Crypto.new.decrypt(encrypted_body.to_s, password: 'abc').to_s
        assert m = Mail::Message.new(clear.to_s)
        assert m.multipart?
        assert_equal 2, m.parts.size
        assert_match /encrypt me/, m.parts.first.body.to_s
        assert_match /Rakefile/, m.parts.last.content_disposition
      end

      should 'decrypt and verify' do
        assert mail = Mail::Gpg.decrypt(@encrypted, { :verify => true, :password => 'abc' })
        assert mail == @mail
        assert mail.parts[1] == @mail.parts[1]
        assert mail.verify_result
        assert signatures = mail.signatures
        assert_equal 1, signatures.size
        assert sig = signatures[0]
        assert sig.to_s =~ /Joe/
        assert sig.valid?
      end
    end
  end
end

