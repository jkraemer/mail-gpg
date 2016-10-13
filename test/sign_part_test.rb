require 'test_helper'
require 'mail/gpg/sign_part'

class SignPartTest < Test::Unit::TestCase
  context 'SignPart' do
    setup do
      set_passphrase('abc')
      @mail = Mail.new do
        to 'jane@foo.bar'
        from 'joe@foo.bar'
        subject 'test'
        body 'i am unsigned'
      end
    end

    should 'roundtrip successfully' do
      set_passphrase('abc')
      signature_part = Mail::Gpg::SignPart.new(@mail, password: 'abc')
      assert Mail::Gpg::SignPart.signature_valid?(@mail, signature_part)
    end
  end
end
