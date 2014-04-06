require 'mail/gpg/verify_result_attribute'

module Mail
  module Gpg
    class VerifiedPart < Mail::Part
      include VerifyResultAttribute
    end
  end
end

