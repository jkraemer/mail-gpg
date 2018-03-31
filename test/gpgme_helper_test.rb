require 'test_helper'

class GpgmeHelperTest < Test::Unit::TestCase

  def check_key_list(keys)
    assert_equal 1, keys.size
    assert_equal GPGME::Key, keys.first.class
    assert_equal 'jane@foo.bar', keys.first.email
  end

  context 'GpgmeHelper' do

    should 'handle empty email list' do
      assert_equal [], Mail::Gpg::GpgmeHelper.send(:keys_for_data, nil)
      assert_equal [], Mail::Gpg::GpgmeHelper.send(:keys_for_data, [])
    end

    context 'with email address' do
      setup do
        @email = 'jane@foo.bar'
      end

      should 'resolve email to gpg keys' do
        assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, @email)
        check_key_list keys
      end

      should 'resolve emails to gpg keys' do
        assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, [@email])
        check_key_list keys
      end

    end

    context 'with key id' do
      setup do
        @key_id = GPGME::Key.find(:public, 'jane@foo.bar').first.sha
      end

      should 'resolve single id  gpg keys' do
        assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, @key_id)
        check_key_list keys
      end
      should 'resolve id list to gpg keys' do
        assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, [@key_id])
        check_key_list keys
      end
    end

    context 'with key fingerprint' do
      setup do
        @key_fpr = GPGME::Key.find(:public, 'jane@foo.bar').first.fingerprint
      end

      should 'resolve single id  gpg keys' do
        assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, @key_fpr)
        check_key_list keys
      end
      should 'resolve id list to gpg keys' do
        assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, [@key_fpr])
        check_key_list keys
      end
    end

    context 'with emails and key data' do
      setup do
        @key = GPGME::Key.find(:public, 'jane@foo.bar').first.export(armor: true).to_s
        @emails = ['jane@foo.bar']
        @key_data = { 'jane@foo.bar' => @key }
      end

      should 'resolve to gpg keys' do
        assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, @emails, @key_data)
        check_key_list keys
      end
    end
  end
end

