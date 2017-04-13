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

      # checks validity of signatures (true / false)
      def signature_valid?
        sigs = self.signatures
        sigs.any? && sigs.all?{|s|s.valid?}
      end

      # list of all signatures from verify_result
      def signatures
        [verify_result].flatten.compact.map do |vr|
          vr.signatures
        end.flatten.compact
      end
    end
  end
end
