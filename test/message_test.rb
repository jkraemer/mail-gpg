require 'test_helper'

class MessageTest < Test::Unit::TestCase

  context "Mail::Message" do

    setup do
      (@mails = Mail::TestMailer.deliveries).clear
      @mail = Mail.new do
        to 'jane@foo.bar'
        from 'joe@foo.bar'
        subject 'test'
        body 'i am unencrypted'
      end
    end

    context "with gpg turned off" do
      setup do
        @mail.deliver
      end

      should "deliver unencrypted mail as usual" do
        assert_equal 1, @mails.size
        assert m = @mails.first
        assert_equal 'test', m.subject
        assert_equal 'i am unencrypted', m.body.to_s
      end
    end

    context "with gpg turned on" do
      setup do
        @mail.gpg encrypt: true
      end

      context "with missing key" do
        setup do
          @mail.to = 'user@host.com'
        end

        should "raise encryption error" do
          assert_raises(GPGME::Error::InvalidValue){
            @mail.deliver
          }
        end

        should "not raise error when encryption errors are turned off" do
          @mail.raise_encryption_errors = false
          @mail.deliver
          assert_equal 0, @mails.size
        end
      end

      context "" do
        setup do
          @mail.deliver
        end

        should "deliver encrypted mail" do
          assert_equal 1, @mails.size
          assert m = @mails.first
          assert_equal 'test', m.subject
          assert m.multipart?
          assert enc_part = m.parts.last
          assert clear = GPGME::Crypto.new.decrypt(enc_part.body.to_s, password: 'abc').to_s
          assert m = Mail::Message.new(clear)
          assert !m.multipart?
          assert_equal 'i am unencrypted', m.body.to_s
        end
      end
    end

    should "respond to gpg method" do
      assert Mail::Message.new.respond_to?(:gpg)
    end

    context "gpg method" do

      should "set and unset delivery_handler" do
        m = Mail.new do
          gpg encrypt: true
        end
        assert m.gpg
        assert dh = m.delivery_handler
        assert_equal Mail::Gpg::DeliveryHandler, dh
        m.gpg false
        assert_nil m.delivery_handler
        assert_nil m.gpg
      end
    end
  end

end
