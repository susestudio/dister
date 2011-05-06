require File.expand_path('../test_helper', __FILE__)

class CoreTest < Test::Unit::TestCase
  context "Using FakeFS -" do
    setup do
      @core = Dister::Core.new
      @core.stubs(:puts)
      @core.options.appliance_id = 1
      STDERR.stubs(:puts)

      FakeFS.activate!
    end

    teardown do
      FakeFS.deactivate!
    end

    context "file uploading" do
      should "not upload non-existing files" do
        assert !@core.file_upload("foo")
      end

      should "upload an existing files" do
        Dister::Utils.stubs(:print)
        STDOUT.stubs(:puts)
        FileUtils.touch "foo"
        StudioApi::File.expects(:find).once.returns([])
        StudioApi::File.expects(:upload).\
                        with(is_a(File), @core.options.appliance_id, {}).\
                        once.\
                        returns(true)
        assert @core.file_upload("foo", {})
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

    context "Build an appliance" do
      setup do
        @core = Dister::Core.new
        @core.options.appliance_id = 1
        @core.stubs(:puts)
        Dister::Utils.stubs(:print)

        # do not clutter unit test results with a progress bar
        silent_pbar = mock()
        silent_pbar.stubs(:set)
        silent_pbar.stubs(:finish)
        ProgressBar.stubs(:new).returns(silent_pbar)

        @core.expects(:verify_status).returns(true)
      end

      context 'an image with the same version already exists' do
        should 'overwrite it if the user wants' do
          build_sequence = sequence('build_sequence')
          StudioApi::RunningBuild.expects(:create).\
            with( { :appliance_id => @core.options.appliance_id,
                    :image_type   => 'oem' } ).\
            once.\
            raises(StudioApi::ImageAlreadyExists).\
            in_sequence(build_sequence)
          @core.shell.expects(:say).in_sequence(build_sequence)
          @core.shell.expects(:ask?).in_sequence(build_sequence).\
                      returns('y')
          fake_build = mock()
          StudioApi::RunningBuild.expects(:create).\
            with( { :appliance_id => @core.options.appliance_id,
                    :image_type   => 'oem',
                    :force        => true } ).\
            once.\
            returns(fake_build).\
            in_sequence(build_sequence)

          fake_build.stubs(:reload)
          fake_build.stubs(:state).returns('finished')
          @core.build
        end

        should 'use the new version specified by the user' do
          new_version = '1.0.1'
          build_sequence = sequence('build_sequence')
          StudioApi::RunningBuild.expects(:create).\
            with( { :appliance_id => @core.options.appliance_id,
                    :image_type   => 'oem' } ).\
            once.\
            raises(StudioApi::ImageAlreadyExists).\
            in_sequence(build_sequence)
          @core.shell.expects(:say).in_sequence(build_sequence)
          @core.shell.expects(:ask?).in_sequence(build_sequence).\
                      returns('n')
          @core.shell.expects(:ask?).in_sequence(build_sequence).\
                      returns(new_version)
          fake_build = mock()
          StudioApi::RunningBuild.expects(:create).\
            with( { :appliance_id => @core.options.appliance_id,
                    :image_type   => 'oem',
                    :version      => new_version } ).\
            once.\
            returns(fake_build).\
            in_sequence(build_sequence)

          fake_build.stubs(:reload)
          fake_build.stubs(:state).returns('finished')
          @core.build
        end

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
