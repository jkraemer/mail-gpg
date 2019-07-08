require 'test_helper'
require 'mail/gpg/version_part'

class VersionPartTest < MailGpgTestCase
  context 'VersionPart' do

    should 'roundtrip successfully' do
      part = Mail::Gpg::VersionPart.new()
      assert Mail::Gpg::VersionPart.isVersionPart?(part)
    end

    should 'return false for non gpg mime type' do
      part = Mail::Gpg::VersionPart.new()
      part.content_type = 'text/plain'
      assert !Mail::Gpg::VersionPart.isVersionPart?(part)
    end

    should 'return false for empty body' do
      part = Mail::Gpg::VersionPart.new()
      part.body = nil
      assert !Mail::Gpg::VersionPart.isVersionPart?(part)
    end

    should 'return false for foul body' do
      part = Mail::Gpg::VersionPart.new()
      part.body = 'non gpg body'
      assert !Mail::Gpg::VersionPart.isVersionPart?(part)
    end

    should 'return true for body with extra content' do
      part = Mail::Gpg::VersionPart.new()
      part.body = "#{part.body} extra content"
      assert Mail::Gpg::VersionPart.isVersionPart?(part)
    end
  end
end
