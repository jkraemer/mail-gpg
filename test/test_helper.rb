require 'test/unit'
require 'shoulda/context'
require 'mail-gpg'
require 'action_mailer'

begin
  require 'pry-nav'
rescue LoadError
end

Mail.defaults do
  delivery_method :test
end
ActionMailer::Base.delivery_method = :test
