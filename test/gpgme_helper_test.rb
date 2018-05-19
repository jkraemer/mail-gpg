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

    # no keys given, assuming they are already in the keychain
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

    # this is a use case we do not really need but it works due to the way
    # Gpgme looks up keys
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

    # this is a use case we do not really need but it works due to the way
    # Gpgme looks up keys
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

    context 'with email addresses' do
      setup do
        @key = GPGME::Key.find(:public, 'jane@foo.bar').first
        @emails = ['jane@foo.bar']
      end

      # probably the most common use case - one or more recipient addresses and a
      # hash mapping them to public key data that the user pasted into a text
      # field at some point
      context 'and key data' do
        setup do
          @key = @key.export(armor: true).to_s
          @key_data = { 'jane@foo.bar' => @key }
        end

        should 'resolve to gpg key for single address' do
          assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, @emails.first, @key_data)
          check_key_list keys
        end

        should 'resolve to gpg keys' do
          assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, @emails, @key_data)
          check_key_list keys
        end

        should 'ignore unknown addresses' do
          assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, ['john@doe.com'], @key_data)
          assert keys.blank?
        end

        should 'ignore invalid key data and not use existing key' do
          assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, ['jane@foo.bar'], { 'jane@foo.bar' => "-----BEGIN PGP\ninvalid key data" })
          assert keys.blank?
        end
      end

      context 'and key id or fpr' do
        setup do
          @key_id = @key.sha
          @key_fpr = @key.fingerprint
          @email = @emails.first
        end

        should 'resolve id to gpg key for single address' do
          assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, @emails.first, { @email => @key_id })
          check_key_list keys
        end

        should 'resolve id to gpg key' do
          assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, @emails, { @email => @key_id })
          check_key_list keys
        end

        should 'resolve fpr to gpg key' do
          assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, @emails, { @email => @key_fpr })
          check_key_list keys
        end

        should 'ignore unknown addresses' do
          assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, ['john@doe.com'], { @email => @key_fpr })
          assert keys.blank?
        end

        should 'ignore invalid key id and not use existing key' do
          assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, @emails, { @email => "invalid key id" })
          assert keys.blank?
        end

      end

      # mapping email addresses to already retrieved key objects or
      # key fingerprints is also possible.
      context 'and key object' do
        setup do
          @key_data = { 'jane@foo.bar' => @key }
        end

        should 'resolve to gpg keys for these addresses' do
          assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, @emails, @key_data)
          check_key_list keys
        end

        should 'ignore unknown addresses' do
          assert keys = Mail::Gpg::GpgmeHelper.send(:keys_for_data, ['john@doe.com'], @key_data)
          assert keys.blank?
        end
      end

    end
  end
end

