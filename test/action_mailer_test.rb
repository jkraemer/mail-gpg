require 'test_helper'

class MyMailer < ActionMailer::Base
  default from: 'joe@foo.bar', to: 'jane@foo.bar'

  def unencrypted
    mail subject: 'unencrypted', body: 'unencrypted mail'
  end

  def encrypted
    mail subject: 'encrypted', body: 'encrypted mail', gpg: true
  end


end

class ActionMailerTest < Test::Unit::TestCase
  context "with action mailer" do
    setup do
      (@emails = ActionMailer::Base.deliveries).clear
    end

    should "send unencrypted mail" do
      MyMailer.unencrypted.deliver
      assert_equal 1, @emails.size
      assert m = @emails.first
      assert_equal 'unencrypted', m.subject
    end


    should "send encrypted mail" do
      assert m = MyMailer.encrypted
      assert true == m.gpg
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

  end
end
