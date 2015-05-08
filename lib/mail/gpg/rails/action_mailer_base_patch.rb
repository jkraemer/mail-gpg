require 'action_mailer/base'

module Mail
  module Gpg
    module Rails

      module ActionMailerPatch
        extend ActiveSupport::Concern

        included do
          cattr_accessor :gpg_encrypt_sender
          alias_method_chain :mail, :gpg
          class << self
            alias_method_chain :deliver_mail, :gpg
          end
        end

        def mail_with_gpg(headers = {}, &block)
          headers = headers.dup
          gpg_options = headers.delete :gpg

          if self.gpg_encrypt_sender &&  self.gpg_encrypt_sender[:keys]
            if gpg_options[:keys]
              gpg_options[:keys].reverse_merge!(self.gpg_encrypt_sender[:keys])
            else
              gpg_options[:keys] = self.gpg_encrypt_sender[:keys]
            end
          end

          mail_without_gpg(headers, &block).tap do |m|
            if gpg_options
              m.gpg gpg_options
            end
          end
        end

        module ClassMethods
          def deliver_mail_with_gpg(mail, &block)
            deliver_mail_without_gpg(mail) do
              Mail::Gpg::DeliveryHandler.deliver_mail mail, &block
            end
          end
        end

      end

      unless ActionMailer::Base.included_modules.include?(ActionMailerPatch)
        ActionMailer::Base.send :include, ActionMailerPatch
      end

    end
  end
end

