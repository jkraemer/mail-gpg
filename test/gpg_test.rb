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


  context "gpg installation" do
    should "have keys for jane and joe" do
      assert joe = GPGME::Key.find(:public, 'joe@foo.bar').first
      assert jane = GPGME::Key.find(:public, 'jane@foo.bar').first
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
      
      should 'decrypt' do
        assert mail = Mail::Gpg.decrypt(@encrypted, { :password => 'abc' })
        assert mail == @mail
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

