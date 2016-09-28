require 'action_mailer/base'

module Mail
  module Gpg
    module Rails

      module ActionMailerPatch

        def self.apply
          unless ActionMailer::Base < InstanceMethods
            ActionMailer::Base.prepend InstanceMethods
            ActionMailer::Base.singleton_class.prepend ClassMethods
          end
        end

        module InstanceMethods
          def mail(headers = {}, &block)
            headers = headers.dup
            gpg_options = headers.delete :gpg
            super(headers, &block).tap do |m|
              if gpg_options
                m.gpg gpg_options
              end
            end
          end
        end

        module ClassMethods
          def deliver_mail(mail, &block)
            super(mail) do
              Mail::Gpg::DeliveryHandler.deliver_mail mail, &block
            end
          end
        end

      end

    end
  end
end

