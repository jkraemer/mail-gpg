require 'test_helper'

class MessageTest < Test::Unit::TestCase

  context "Mail::Message" do

    setup do
      set_passphrase('abc')
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
        assert !m.encrypted?
        assert_equal 'i am unencrypted', m.body.to_s
      end

      should "raise encoding error" do
        assert_equal 1, @mails.size
        assert m = @mails.first
        assert_equal 'test', m.subject
        assert_raises(EncodingError){
          m.decrypt(:password => 'abc')
        }
      end
    end

    context "with gpg signing only" do
      setup do
        @mail.gpg sign: true, password: 'abc'
      end

      context 'with multiple parts' do
        setup do
          p = Mail::Part.new do
            body 'and another part'
          end
          @mail.add_part p
          p = Mail::Part.new do
            body 'and a third part'
          end
          @mail.add_part p

          @mail.deliver
          @signed = @mails.first
          @verified = @signed.verify
        end

        should 'verify signature' do
          assert @verified.signature_valid?
        end

        should 'have original three parts' do
          assert_equal 3, @mail.parts.size
          assert_equal 3, @verified.parts.size
          assert_equal 'i am unencrypted', @verified.parts[0].body.to_s
          assert_equal 'and another part', @verified.parts[1].body.to_s
          assert_equal 'and a third part', @verified.parts[2].body.to_s
        end
      end

      context "" do
        setup do
          @mail.header['Auto-Submitted'] = 'foo'
          @mail.header['List-Help'] = 'https://lists.example.org/help/'
          @mail.header['List-Id'] = 'test.lists.example.org'
          @mail.header['List-Owner'] = 'test-owner@lists.example.org'
          @mail.header['List-Post'] = '<mailto:test@lists.example.org> (Subscribers only)'
          @mail.header['List-Unsubscribe'] = 'bar'
          @mail.header['Date'] = 'Sun, 25 Dec 2016 16:56:52 -0500'
          @mail.header['OpenPGP'] = 'id=0x0123456789abcdef0123456789abcdefdeadbeef (present on keyservers); (Only encrypted and signed emails are accepted)'
          @mail.deliver
        end

        should 'keep custom header value' do
          assert_equal 'foo', @mails.first.header['Auto-Submitted'].value
          assert_equal 'https://lists.example.org/help/', @mails.first.header['List-Help'].value
          assert_equal 'test.lists.example.org', @mails.first.header['List-Id'].value
          assert_equal 'test-owner@lists.example.org', @mails.first.header['List-Owner'].value
          assert_equal '<mailto:test@lists.example.org> (Subscribers only)', @mails.first.header['List-Post'].value
          assert_equal 'bar', @mails.first.header['List-Unsubscribe'].value
          assert_equal 'Sun, 25 Dec 2016 16:56:52 -0500', @mails.first.header['Date'].value
          assert_equal 'id=0x0123456789abcdef0123456789abcdefdeadbeef (present on keyservers); (Only encrypted and signed emails are accepted)', @mails.first.header['OpenPGP'].value
        end

        should "deliver signed mail" do
          assert_equal 1, @mails.size
          assert m = @mails.first
          assert_equal 'test', m.subject
          assert !m.encrypted?
          assert m.signed?
          assert m.multipart?
          assert sign_part = m.parts.last
          GPGME::Crypto.new.verify(sign_part.body.to_s, signed_text: m.parts.first.encoded) do |sig|
            assert sig.valid?
          end
        end

        should 'verify signed mail' do
          assert m = @mails.first
          assert verified = m.verify
          assert verified.signature_valid?
          assert !verified.multipart?
          assert_equal 'i am unencrypted', verified.body.to_s
        end

        should "fail signature on tampered body" do
          assert_equal 1, @mails.size
          assert m = @mails.first
          assert_equal 'test', m.subject
          assert !m.encrypted?
          assert m.signed?
          assert m.multipart?
          assert verified = m.verify
          assert verified.signature_valid?
          m.parts.first.body = 'replaced body'
          assert verified = m.verify
          assert !verified.signature_valid?
        end
      end
    end

    context 'with encryption and signing' do
      setup do
        @mail.gpg encrypt: true, sign: true, password: 'abc'
        @mail.deliver
      end

      should 'decrypt and check signature' do
        assert_equal 1, @mails.size
        assert m = @mails.first
        assert_equal 'test', m.subject
        assert m.multipart?
        assert m.encrypted?
        assert decrypted = m.decrypt(:password => 'abc', verify: true)
        assert_equal 'test', decrypted.subject
        assert decrypted == @mail
        assert_equal 'i am unencrypted', decrypted.body.to_s
        assert decrypted.signature_valid?
        assert_equal 1, decrypted.signatures.size
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
          assert_raises(Mail::Gpg::MissingKeysError){
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
          assert m.encrypted?
          assert enc_part = m.parts.last
          assert clear = GPGME::Crypto.new.decrypt(enc_part.body.to_s, password: 'abc').to_s
          assert m = Mail::Message.new(clear)
          assert !m.multipart?
          assert_equal 'i am unencrypted', m.body.to_s
        end

        should "decrypt" do
          assert_equal 1, @mails.size
          assert m = @mails.first
          assert_equal 'test', m.subject
          assert m.multipart?
          assert m.encrypted?
          assert decrypted = m.decrypt(:password => 'abc')
          assert_equal 'test', decrypted.subject
          assert decrypted == @mail
          assert_equal 'i am unencrypted', decrypted.body.to_s
        end

        should "raise bad passphrase on decrypt" do
          assert_equal 1, @mails.size
          assert m = @mails.first
          assert_equal 'test', m.subject
          # incorrect passphrase
          if GPG21 == true
            set_passphrase('incorrect')
            expected_exception = GPGME::Error::DecryptFailed
          else
            expected_exception = GPGME::Error::BadPassphrase
          end
          assert_raises(expected_exception){
            m.decrypt(:password => 'incorrect')
          }
          # no passphrase
          assert_raises(expected_exception){
            m.decrypt
          }
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
