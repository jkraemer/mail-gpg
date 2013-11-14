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
    assert_equal 'application/pgp-encrypted; charset=UTF-8', v_part.content_type

    assert_equal 'application/octet-stream; name=encrypted.asc',
    enc_part.content_type
  end


  def check_content(mail = @mail, encrypted = @encrypted)
    assert enc = encrypted.parts.last
    assert clear = GPGME::Crypto.new.decrypt(enc.to_s, password: 'abc').to_s
    assert_match /encrypt me/, clear
    assert_equal mail.to_s, clear
  end

  def check_signature(mail = @mail, signed = @signed)
    assert signature = signed.parts.detect{|p| p.content_type =~ /signature\.asc/}.body.to_s
    GPGME::Crypto.new.verify(signature, signed_text: mail.encoded) do |sig|
      assert true == sig.valid?
    end
  end

  def check_mime_structure_signed(mail = @mail, signed = @signed)
    assert_equal 2, signed.parts.size
    sign_part, orig_part = signed.parts

    assert_equal 'application/pgp-signature; name=signature.asc', sign_part.content_type
    assert_equal orig_part.content_type, @mail.content_type
  end

  def check_headers_signed(mail = @mail, signed = @signed)
    assert_equal mail.to, signed.to
    assert_equal mail.cc, signed.cc
    assert_equal mail.bcc, signed.bcc
    assert_equal mail.subject, signed.subject
  end

  context "gpg installation" do
    should "have keys for jane and joe" do
      assert joe = GPGME::Key.find(:public, 'joe@foo.bar').first
      assert jane = GPGME::Key.find(:public, 'jane@foo.bar').first
    end
  end

  context "gpg signed" do
    setup do
      @mail = Mail.new do
        to 'joe@foo.bar'
        from 'jane@foo.bar'
        subject 'test test'
        body 'sign me!'
      end
    end

    context 'simple mail' do
      setup do
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

    context 'mail with custom header' do
      setup do
        @mail.header['X-Custom-Header'] = 'custom value'
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

    context 'multipart mail' do
      setup do
        @mail.add_file 'Rakefile'
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
        assert original_part = @signed.parts.last
        assert original_part.multipart?
        assert_equal 2, original_part.parts.size
        assert_match /sign me!/, original_part.parts.first.body.to_s
        assert_match /Rakefile/, original_part.parts.last.content_disposition
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
      end
    end

    context 'mail with custom header' do
      setup do
        @mail.header['X-Custom-Header'] = 'custom value'
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

      should 'have multiple parts in encrypted content' do
        assert encrypted_body = @encrypted.parts.last.to_s
        assert clear = GPGME::Crypto.new.decrypt(encrypted_body.to_s, password: 'abc').to_s
        assert m = Mail::Message.new(clear.to_s)
        assert m.multipart?
        assert_equal 2, m.parts.size
        assert_match /encrypt me/, m.parts.first.body.to_s
        assert_match /Rakefile/, m.parts.last.content_disposition
      end

      should 'decrypt' do
        assert mail = Mail::Gpg.decrypt(@encrypted, { :password => 'abc' })
        assert mail == @mail
        assert mail.parts[1] == @mail.parts[1]
      end
    end
  end
end

