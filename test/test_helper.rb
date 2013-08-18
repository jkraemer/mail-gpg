require 'test/unit'
require 'shoulda/context'
require 'mail-gpg'
require 'pry-nav'
require 'action_mailer'

Mail.defaults do
  delivery_method :test
end
ActionMailer::Base.delivery_method = :test
