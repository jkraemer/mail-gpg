module Mail
  module Gpg
    module VerifyResultAttribute
      # the result of signature verification, as provided by GPGME
      def verify_result(result = nil)
        if result
          self.verify_result = result
        else
          @verify_result
        end
      end
      def verify_result=(result)
        @verify_result = result
      end
    end
  end
end
