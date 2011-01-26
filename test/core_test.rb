require File.expand_path('../test_helper', __FILE__)

class CoreTest < Test::Unit::TestCase
  context "Using FakeFS -" do
    setup do
      FakeFS.activate!
    end

    teardown do
      FakeFS.deactivate!
    end

    context "file uploading" do
      should "not upload non-existing files" do
        STDERR.stubs(:puts)
        core = Dister::Core.new
        assert !core.file_upload("foo")
      end

      should "upload an existing files" do
        FileUtils.touch "foo"
        core = Dister::Core.new
        StudioApi::File.expects(:upload).\
                        with(is_a(File), nil, {}).\
                        once.\
                        returns(true)
        assert core.file_upload("foo", {})
      end
    end

    context "While executing 'dister bundle' it" do

      setup do
        @core = Dister::Core.new
        @core.stubs(:puts)
      end

      should 'package all required gems' do
        @core.expects(:system).with("cd #{Dister::Core::APP_ROOT}").once.returns(true)
        File.expects(:exists?).once.returns(true)
        @core.expects(:system).with("rm -R vendor/cache").once.returns(true)
        @core.expects(:system).with("bundle package").once.returns(true)
        @core.package_gems
      end

      should "create a tarball of the application's source files" do
        @core.expects(:system).with("cd #{Dister::Core::APP_ROOT}").once.returns(true)
        File.expects(:exists?).once.returns(true)
        @core.expects(:system).with("rm ./.dister/application.tar.gz").once.returns(true)
        @core.expects(:system).with("tar -czf ./.dister/application.tar.gz . --exclude=.dister").once.returns(true)
        @core.package_app
      end

    end

  end

end
