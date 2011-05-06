require File.expand_path('../test_helper', __FILE__)

class UtilsTest < Test::Unit::TestCase

  include Dister::Utils

  should "return readable file sizes" do
    assert_equal readable_file_size(12233, 0), "12 KB"
    assert_equal readable_file_size(12233, 2), "11.95 KB"
  end

end
