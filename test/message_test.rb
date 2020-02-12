require 'test_helper'

class MessageTest < MailGpgTestCase

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

    context "with multi line utf-8 body and gpg signing only" do
      setup do
        @mail.charset = 'UTF-8'
        @body = <<-END
        one
        two
        euro €
        three
        END

        @mail.body = @body
        @mail.gpg sign: true, password: 'abc'
        @mail.deliver
        @signed = Mail.new @mails.first.to_s
        @verified = @signed.verify
        # Mail gem from 2.7.1 onwards converts "\n" to "\r\n"
        @body = Mail::Utilities.to_crlf(@body)
      end

      should 'keep body unchanged' do
        body = @verified.body.to_s.force_encoding 'UTF-8'
        assert_equal @body, body
      end

      should 'verify signed mail' do
        refute @signed.encrypted?
        assert @signed.multipart?, "message should be multipart"
        assert @signed.signed?, "message should be signed"
        assert sign_part = @signed.parts.last
        GPGME::Crypto.new.verify(sign_part.body.to_s, signed_text: @signed.parts.first.encoded) do |sig|
          assert sig.valid?, "Signature is not valid"
        end

        assert @verified.signature_valid?, "Signature check failed!"
        refute @verified.multipart?
      end

    end

    context "with gpg signing only" do
      setup do
        @mail.gpg sign: true, password: 'abc'
      end

      context 'with attachment' do
        setup do
          p = Mail::Part.new do
            body "and\nanother part euro €"
          end
          @mail.add_part p
          # if we do not force it to binary, the line ending is changed to CRLF. WTF?
          @attachment_data = "this is\n € not an image".force_encoding(Encoding::BINARY)
          @mail.attachments['test.jpg'] = { mime_type: 'image/jpeg',
                                            content: @attachment_data }

          @mail.deliver
          @signed = Mail.new @mails.first.to_s
          @verified = @signed.verify
        end

        should 'verify signature' do
          assert @verified.signature_valid?
        end

        should 'have original three parts' do
          assert_equal 3, @verified.parts.size
          assert_equal 'i am unencrypted', @verified.parts[0].body.to_s
          assert_equal "and\r\nanother part euro €", @verified.parts[1].body.to_s.force_encoding('UTF-8')
          assert attachment = @verified.parts[2]
          assert attachment.attachment?
          assert_equal "attachment; filename=test.jpg", attachment.content_disposition
          assert_equal @attachment_data, attachment.body.to_s
        end

      end

      context 'with multiple parts' do
        setup do
          p = Mail::Part.new do
            body "and\nanother part euro €"
          end
          @mail.add_part p
          p = Mail::Part.new do
            content_type "text/html; charset=UTF-8"
            body "and an\nHTML part €"
          end
          @mail.add_part p

          @mail.deliver
          @signed = Mail.new @mails.first.to_s
          @verified = @signed.verify
        end

        should 'verify signature' do
          assert @verified.signature_valid?
        end

        should 'have original three parts' do
          assert_equal 3, @mail.parts.size
          assert_equal 3, @verified.parts.size
          assert_equal 'i am unencrypted', @verified.parts[0].body.to_s
          assert_equal "and\r\nanother part euro €", @verified.parts[1].body.to_s.force_encoding('UTF-8')
          assert_equal "and an\r\nHTML part €", @verified.parts[2].body.to_s.force_encoding('UTF-8')
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

    context 'utf-8 with encryption and signing' do
      setup do
        @body = "one\neuro €"
        @mail.charset = 'UTF-8'
        @mail.body @body
        @mail.gpg encrypt: true, sign: true, password: 'abc'
        @mail.deliver
        assert_equal 1, @mails.size
        assert m = @mails.first
        @received = Mail.new m.to_s
      end

      should 'decrypt and check signature' do
        m = @received
        assert_equal 'test', m.subject
        assert m.multipart?
        assert m.encrypted?
        assert decrypted = m.decrypt(:password => 'abc', verify: true)
        assert_equal 'test', decrypted.subject
        assert decrypted == @mail
        assert_equal "one\r\neuro €", decrypted.body.to_s.force_encoding('UTF-8')
        assert decrypted.signature_valid?
        assert_equal 1, decrypted.signatures.size
      end

      should 'preserve headers in raw_source output' do
        m = @received
        assert decrypted = m.decrypt(:password => 'abc', verify: true)
        assert s = decrypted.raw_source
        assert s.include?('From: joe@foo.bar')
        assert s.include?('To: jane@foo.bar')
        assert s.include?('Subject: test')

        body = decrypted.body.to_s.force_encoding('UTF-8')
        assert body.include?('euro €'), s
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
          if @gpg_utils.preset_passphrases?
            set_passphrase('incorrect')
            # expected_exception = GPGME::Error::DecryptFailed
            # I dont know why.
            expected_exception = EOFError
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
