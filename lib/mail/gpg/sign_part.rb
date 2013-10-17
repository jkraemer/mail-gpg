module Mail
	module Gpg
		class SignPart < Mail::Part

			def initialize(cleartext_mail, options = {})
				signature = sign(cleartext_mail.encoded, options)
				super() do
					body signature.to_s
					content_type "application/pgp-signature; name=\"signature.asc\""
					content_disposition 'attachment; filename="signature.asc"'
					content_description 'OpenPGP digital signature'
				end	
			end	

			private

			def sign(plain, options = {})
				options.merge!({
					armor: true,
					signer: options.delete(:sign_as),
					mode: GPGME::SIG_MODE_DETACH
				})
				crypto = GPGME::Crypto.new
				crypto.sign GPGME::Data.new(plain), options
			end

		end
	end
end
