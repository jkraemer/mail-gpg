require 'gpgme'
require 'mail/gpg/verify_result_attribute'

# extend GPGME::Data with an attribute to hold the result of signature
# verifications
class GPGME::Data
  include Mail::Gpg::VerifyResultAttribute
end

