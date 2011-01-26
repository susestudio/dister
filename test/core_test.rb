require File.expand_path('../test_helper', __FILE__)

class CoreTest < Test::Unit::TestCase
  context "Run with FakeFS" do
    setup do
      FakeFS.activate!
    end

    teardown do
      FakeFS.deactivate!
    end

    context "file uploading" do
      should "not upload non-existing files" do
        core = Dister::Core.new
        assert !core.file_upload("foo", 123)
      end
      
      should "upload an existing files" do
        FileUtils.touch "foo"
        options = {:appliance_id => 123,
                   :permission => "0755"}
        core = Dister::Core.new
        StudioApi::File.expects(:upload).\
                        with(is_a(File), options).\
                        once.\
                        returns(true)
        assert core.file_upload("foo", 123, options)
      end
    end
  end
end
