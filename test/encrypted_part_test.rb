require 'test_helper'
require 'mail/gpg/encrypted_part'

class EncryptedPartTest < Test::Unit::TestCase

  def check_key_list(keys)
    assert_equal 1, keys.size
    assert_equal GPGME::Key, keys.first.class
    assert_equal 'jane@foo.bar', keys.first.email
  end

  context 'EncryptedPart' do
    setup do
      mail = Mail.new do
        to 'jane@foo.bar'
        from 'joe@foo.bar'
        subject 'test'
        body 'i am unencrypted'
      end
      @part = Mail::Gpg::EncryptedPart.new(mail, recipients: ['jane@foo.bar'])
    end

    should 'have binary content type and name' do
      assert_equal 'application/octet-stream; name=encrypted.asc', @part.content_type
    end

    should 'have description' do
      assert_match(/openpgp/i, @part.content_description)
    end

    should 'have inline disposition and default filename' do
      assert_equal 'inline; filename=encrypted.asc', @part.content_disposition
    end

  end
end
