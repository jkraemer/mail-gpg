module Mail
  module Gpg
    class DeliveryHandler

      def self.deliver_mail(mail)
        if mail.gpg
          encrypted_mail = nil
          begin
            options = TrueClass === mail.gpg ? {} : mail.gpg
            encrypted_mail = Mail::Gpg.encrypt(mail, options)
          rescue Exception
            raise $! if mail.raise_encryption_errors
          end
          encrypted_mail.deliver if encrypted_mail
        else
          yield
        end
      rescue Exception
        raise $! if mail.raise_delivery_errors
      end

    end
  end
end
