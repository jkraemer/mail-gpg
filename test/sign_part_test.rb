require 'mail/gpg/sign_part'

class SignPartTest < Test::Unit::TestCase
	context 'SignPart' do
		setup do
			mail = Mail.new do
				to 'jane@foo.bar'
				from 'joe@foo.bar'
				subject 'test'
				body 'i am unsigned'
			end
			@part = Mail::Gpg::SignPart.new(mail)
		end
	end
end
