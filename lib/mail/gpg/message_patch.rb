require 'mail/gpg/delivery_handler'
require 'mail/gpg/verify_result_attribute'

module Mail
  module Gpg
    module MessagePatch

      def self.included(base)
        base.class_eval do
          attr_accessor :raise_encryption_errors
          include VerifyResultAttribute
        end
      end

      # turn on gpg encryption / set gpg options.
      #
      # options are:
      #
      # encrypt: encrypt the message. defaults to true
      # sign: also sign the message. false by default
      # sign_as: UIDs to sign the message with
      #
      # See Mail::Gpg methods encrypt and sign for more
      # possible options
      #
      # mail.gpg encrypt: true
      # mail.gpg encrypt: true, sign: true
      # mail.gpg encrypt: true, sign_as: "other_address@host.com"
      #
      # future versions will also support sign-only mode:
      # mail.gpg sign_as: 'jane@doe.com', encrypt: false
      #
      # To turn off gpg encryption use:
      # mail.gpg false
      #
      def gpg(options = nil)
        case options
        when nil
          @gpg
        when false
          @gpg = nil
          if Mail::Gpg::DeliveryHandler == delivery_handler
            self.delivery_handler = nil
          end
          nil
        end
        if options
          self.raise_encryption_errors = true if raise_encryption_errors.nil?
          @gpg = options
          self.delivery_handler ||= Mail::Gpg::DeliveryHandler
        else
          @gpg
        end
      end

      def encrypted?
        Mail::Gpg.encrypted?(self)
      end

      def decrypt(options = {})
        Mail::Gpg.decrypt(self, options)
      end

      def signed?
        Mail::Gpg.signed?(self)
      end

      def signature_valid?(options = {})
        Mail::Gpg.signature_valid?(self, options)
      end
    end
  end
end

unless Mail::Message.included_modules.include?(Mail::Gpg::MessagePatch)
  Mail::Message.send :include, Mail::Gpg::MessagePatch
end
