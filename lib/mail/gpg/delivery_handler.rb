module Mail
  module Gpg
    class DeliveryHandler

      def self.deliver_mail(mail)
        if mail.gpg
          encrypted_mail = nil
          begin
            options = TrueClass === mail.gpg ? { encrypt: true } : mail.gpg
            if options[:encrypt]
              encrypted_mail = Mail::Gpg.encrypt(mail, options)
            elsif options[:sign] || options[:sign_as]
              encrypted_mail = Mail::Gpg.sign(mail, options)
            else
              # encrypt and sign are off -> do not encrypt or sign
              yield
            end
          rescue Exception
            raise $! if mail.raise_encryption_errors
          end
          if encrypted_mail
            if dm = mail.delivery_method
              encrypted_mail.instance_variable_set :@delivery_method, dm
            end
            encrypted_mail.perform_deliveries = mail.perform_deliveries
            encrypted_mail.raise_delivery_errors = mail.raise_delivery_errors
            encrypted_mail.deliver
          end
        else
          yield
        end
      rescue Exception
        raise $! if mail.raise_delivery_errors
      end

    end
  end
end
