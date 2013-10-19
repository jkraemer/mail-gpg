require 'mail'
require 'mail/message'
require 'gpgme'

require 'mail/gpg/version'
require 'mail/gpg/version_part'
require 'mail/gpg/decrypted_part'
require 'mail/gpg/encrypted_part'
require 'mail/gpg/message_patch'
require 'mail/gpg/rails'

module Mail
  module Gpg

		mattr_accessor :default_keyserver_url

    # options are:
    # :sign : sign message using the sender's private key
    # :sign_as : sign using this key (give the corresponding email address)
    # :passphrase: passphrase for the signing key
    # :keys : A hash mapping recipient email addresses to public keys or public
    # key ids. Imports any keys given here that are not already part of the
    # local keychain before sending the mail.
    # :always_trust : send encrypted mail to untrusted receivers, true by default
    def self.encrypt(cleartext_mail, options = {})
      receivers = []
      receivers += cleartext_mail.to if cleartext_mail.to
      receivers += cleartext_mail.cc if cleartext_mail.cc
      receivers += cleartext_mail.bcc if cleartext_mail.bcc

      if options[:sign_as]
        options[:sign] = true
        options[:signers] = options.delete(:sign_as)
      elsif options[:sign]
        options[:signers] = cleartext_mail.from
      end

      Mail.new do
        self.perform_deliveries = cleartext_mail.perform_deliveries
        %w(from to cc bcc subject reply_to in_reply_to).each do |field|
          send field, cleartext_mail.send(field)
        end
        cleartext_mail.header.fields.each do |field|
          header[field.name] = field.value if field.name =~ /^X-/
        end
        add_part VersionPart.new
        add_part EncryptedPart.new(cleartext_mail,
                                   options.merge({recipients: receivers}))
        content_type "multipart/encrypted; protocol=\"application/pgp-encrypted\"; boundary=#{boundary}"
        body.preamble = options[:preamble] || "This is an OpenPGP/MIME encrypted message (RFC 2440 and 3156)"
      end
    end

    def self.decrypt(encrypted_mail, options = {})
      if (encrypted_mail.has_content_type? && 
          'multipart/encrypted' == encrypted_mail.mime_type &&
          'application/pgp-encrypted' == encrypted_mail.content_type_parameters[:protocol])
         decrypt_pgp_mime(encrypted_mail, options)
      else
        raise EncodingError, "Unsupported encryption format '#{encrypted_mail.content_type}'"
      end
    end

		def self.get_keyserver_url(options = {})
			url = TrueClass === options[:key_server] ? nil : options[:key_server]
			if url.blank?
				if default_keyserver_url.present?
					url = default_keyserver_url
				elsif res = exec_cmd("gpgconf --list-options gpgs 2>&1 | grep keyserver 2>&1")
					url = URI.decode(res.split(":").last.split("\"").last.strip)
				elsif res = exec_cmd("gpg --gpgconf-list 2>&1 | grep gpgconf-gpg.conf 2>&1")
					conf_file = res.split(":").last.split("\"").last.strip
					if res = exec_cmd("cat #{conf_file} 2>&1 | grep ^keyserver 2>&1")
						url = res.split(" ").last.strip
					end
				end
			end
			url
		end

		def self.get_keys_from_pk_server(email_or_sha, options = {})
			require 'net/http'
			return [] unless url = get_keyserver_url(options)
			uri = URI.parse("#{url}/pks/lookup?op=get&options=mr&search=#{URI.encode(email_or_sha)}")
			req = Net::HTTP::Get.new(uri.to_s)
			res = Net::HTTP.start(uri.host, 11371) do |http|
				http.request req
			end
			if res.code =~ /200/
				fprs = GPGME::Key.import(res.body).imports.map(&:fpr)
				GPGME::Key.find(:public, fprs, :encrypt)
			else
				[]
			end
		end
    
    private

		def self.exec_cmd(cmd)
			res = `#{cmd}`
			return nil if $?.exitstatus != 0
			res
		end

    # decrypts PGP/MIME (RFC 3156, section 4) encrypted mail
    def self.decrypt_pgp_mime(encrypted_mail, options)
      # MUST containt exactly two body parts
      if encrypted_mail.parts.length != 2
        raise EncodingError, "RFC 3136 mandates exactly two body parts, found '#{encrypted_mail.parts.length}'"
      end
      if !VersionPart.isVersionPart? encrypted_mail.parts[0]
        raise EncodingError, "RFC 3136 first part not a valid version part '#{encrypted_mail.parts[0]}'"
      end
      Mail.new(DecryptedPart.new(encrypted_mail.parts[1], options))
    end
  end
end
