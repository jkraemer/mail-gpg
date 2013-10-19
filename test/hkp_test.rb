require 'test_helper'
require 'hkp'

class HkpTest < Test::Unit::TestCase

  context "keyserver setup" do

    context "with url specified" do

      setup do
        @hkp = Hkp.new("hkp://my-key-server.net")
      end

      should "use specified keyserver" do
        assert url = @hkp.instance_variable_get("@keyserver")
        assert_equal "hkp://my-key-server.net", url
      end

    end

    context "without url specified" do
    
      setup do
        @hkp = Hkp.new
      end

      should "have found a non-empty keyserver" do
        assert url = @hkp.instance_variable_get("@keyserver")
        assert !url.blank?
      end

    end

  end

end
