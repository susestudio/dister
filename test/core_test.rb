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
        STDOUT.stubs(:puts)
        FileUtils.touch "foo"
        core = Dister::Core.new
        core.stubs(:puts)
        StudioApi::File.expects(:find).once.returns([])
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
        File.expects(:exists?).returns(true)
        @core.expects(:system).with("cd #{Dister::Core::APP_ROOT}").once.returns(true)
        File.expects(:exists?).returns(true)
        @core.expects(:system).with("rm -R vendor/cache").once.returns(true)
        @core.expects(:system).with("bundle package").once.returns(true)
        @core.package_gems
      end

      should "create a tarball of the application's source files" do
        File.stubs(:exists?).returns(true)
        @core.expects(:system).with("rm .dister/dister_application.tar.gz").once.returns(true)
        @core.expects(:system).with("tar -czf .dister/dister_application.tar.gz ../dister/ --exclude=.dister &> /dev/null").once.returns(true)
        @core.package_app
      end
    end

    context "verify status" do
      setup do
        @core = Dister::Core.new
        @core.stubs(:puts)
        Dister::Utils.stubs(:print)
      end

      should "raise an error if something is wrong" do
        STDOUT.stubs(:puts)
        fake_status = mock()
        fake_status.stubs(:state).returns("BOOM")
        fake_status.stubs(:issues).returns("Bad mood")
        fake_appliance = mock()
        fake_appliance.stubs(:edit_url).returns("http://susestudio.com")
        fake_appliance.stubs(:status).returns(fake_status)
        @core.stubs(:appliance).returns(fake_appliance)
        assert_raise SystemExit do
          @core.verify_status
        end
      end
    end
  end
end
