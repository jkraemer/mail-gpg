require 'test_helper'
require 'mail/gpg/decrypted_part'
require 'mail/gpg/encrypted_part'

class DecryptedPartTest < Test::Unit::TestCase
  context 'DecryptedPart' do
    setup do
      @mail = Mail.new do
        to 'jane@foo.bar'
        from 'joe@foo.bar'
        subject 'test'
        body 'i am unencrypted'
      end
      @part = Mail::Gpg::EncryptedPart.new(@mail, { :sign => true, :password => 'abc' })
    end

    should 'decrypt' do
      assert mail = Mail::Gpg::DecryptedPart.new(@part, { :password => 'abc' })
      assert mail == @mail
      assert mail.message_id == @mail.message_id
      assert mail.message_id != @part.message_id
    end

    should 'decrypt and verify' do
      assert mail = Mail::Gpg::DecryptedPart.new(@part, { :verify => true, :password => 'abc' })
      assert mail == @mail
      assert mail.message_id == @mail.message_id
      assert mail.message_id != @part.message_id
      assert vr = mail.verify_result
      assert sig = vr.signatures.first
      assert sig.to_s=~ /Joe/
      assert sig.valid?
    end

    should 'raise encoding error for non gpg mime type' do
      part = Mail::Part.new(@part)
      part.content_type = 'text/plain'
      assert_raise(EncodingError) { Mail::Gpg::DecryptedPart.new(part) }
    end


  end
end
