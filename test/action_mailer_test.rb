require 'test_helper'

class MyMailer < ActionMailer::Base
  default from: 'joe@foo.bar', to: 'jane@foo.bar'

  def unencrypted(bouncy=false)
    mail subject: 'unencrypted', body: 'unencrypted mail', return_path: (bouncy && bounce_address)
  end

  def encrypted_with_key(bouncy=false)
    mail subject: 'encrypted', body: 'encrypted mail', return_path: (bouncy && bounce_address), gpg: {
      encrypt: true, keys: { "john@foo.bar" => "secret key" }
    }
  end

  def encrypted(bouncy=false)
    mail subject: 'encrypted', body: 'encrypted mail', return_path: (bouncy && bounce_address), gpg: {encrypt: true}
  end

  def signed(bouncy=false)
    mail  from: 'jane@foo.bar',
          to: 'joe@foo.bar',
          subject: 'signed',
          body: 'signed mail',
          return_path: (bouncy && bounce_address),
          gpg: {
            sign: true,
            password: 'abc'
          }
  end

  private

  def bounce_address
    SecureRandom.uuid + "@bounces.example.com"
  end

end

class ActionMailerTest < Test::Unit::TestCase
  context 'without return_path' do
    setup do
      (@emails = ActionMailer::Base.deliveries).clear
    end

    context "with action mailer" do
      should "send unencrypted mail" do
        MyMailer.unencrypted.deliver
        assert_equal 1, @emails.size
        assert m = @emails.first
        assert_equal 'unencrypted', m.subject
      end

      should "send encrypted mail" do
        assert m = MyMailer.encrypted
        assert true == m.gpg[:encrypt]
        m.deliver
        assert_equal 1, @emails.size
        assert m = @emails.first
        assert_equal 'encrypted', m.subject
        assert_equal 2, m.parts.size
        assert encrypted = m.parts.detect{|p| p.content_type =~ /encrypted\.asc/}
        assert clear = GPGME::Crypto.new.decrypt(encrypted.body.to_s, password: 'abc')
        m = Mail.new clear
        assert_equal 'encrypted mail', m.body.to_s
      end

      should "send signed mail" do
        assert m = MyMailer.signed
        assert true == m.gpg[:sign]
        m.deliver
        assert_equal 1, @emails.size
        assert delivered = @emails.first
        assert_equal 'signed', delivered.subject
        assert_equal 2, delivered.parts.size
        assert sign_part = delivered.parts.detect{|p| p.content_type =~ /signature\.asc/}
        assert signed_part = delivered.parts.detect{|p| p.content_type !~ /signature\.asc/}
        GPGME::Crypto.new.verify(sign_part.body.to_s, signed_text: signed_part.encoded) do |sig|
          assert sig.valid?
        end
      end

       should "encrypt with senders key if provided global configuration" do
        before_run = ActionMailer::Base.gpg_encrypt_sender
        ActionMailer::Base.gpg_encrypt_sender = {
          keys: { "john@foo.bar" => "somekey" }
        }
        assert m = MyMailer.encrypted
        assert true == m.gpg[:encrypt]
        assert "somekey" == m.gpg[:keys]["john@foo.bar"]
        ActionMailer::Base.gpg_encrypt_sender = before_run
      end

      should "prefer key specified by the mailer over global configuration" do
        before_run = ActionMailer::Base.gpg_encrypt_sender
        ActionMailer::Base.gpg_encrypt_sender = {
          keys: { "john@foo.bar" => "somekey" }
        }
        assert m = MyMailer.encrypted_with_key
        assert true == m.gpg[:encrypt]
        assert "secret key" == m.gpg[:keys]["john@foo.bar"]
        ActionMailer::Base.gpg_encrypt_sender = before_run
      end

    end
  end

  context 'with return_path' do
    setup do
      (@emails = ActionMailer::Base.deliveries).clear
    end

    context "with action mailer" do
      should "send unencrypted mail" do
        MyMailer.unencrypted(true).deliver
        assert_equal 1, @emails.size
        assert m = @emails.first
        assert_match /@bounces\.example\.com\z/, m.return_path
        assert_equal 'unencrypted', m.subject
      end

      should "send encrypted mail" do
        assert m = MyMailer.encrypted(true)
        assert true == m.gpg[:encrypt]
        m.deliver
        assert_equal 1, @emails.size
        assert m = @emails.first
        assert_match /@bounces\.example\.com\z/, m.return_path
        assert_equal 'encrypted', m.subject
        assert_equal 2, m.parts.size
        assert encrypted = m.parts.detect{|p| p.content_type =~ /encrypted\.asc/}
        assert clear = GPGME::Crypto.new.decrypt(encrypted.body.to_s, password: 'abc')
        m = Mail.new clear
        assert_equal 'encrypted mail', m.body.to_s
      end

      should "send signed mail" do
        assert m = MyMailer.signed(true)
        assert true == m.gpg[:sign]
        m.deliver
        assert_equal 1, @emails.size
        assert delivered = @emails.first
        assert_match /@bounces\.example\.com\z/, delivered.return_path
        assert_equal 'signed', delivered.subject
        assert_equal 2, delivered.parts.size
        assert sign_part = delivered.parts.detect{|p| p.content_type =~ /signature\.asc/}
        assert signed_part = delivered.parts.detect{|p| p.content_type !~ /signature\.asc/}
        GPGME::Crypto.new.verify(sign_part.body.to_s, signed_text: signed_part.encoded) do |sig|
          assert sig.valid?
        end
      end
    end
  end
end
