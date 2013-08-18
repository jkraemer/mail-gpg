begin
  require 'action_mailer'
  require 'active_support'
  require 'mail/gpg/rails/action_mailer_base_patch'
rescue LoadError
  # no actionmailer, do nothing
end

