require File.expand_path('../test_helper', __FILE__)

if !defined? FakeTemplates
  Struct.new("FakeTemplate", :name, :basesystem, :appliance_id, :description)

  FakeTemplates = []
  YAML.load_file(File.expand_path('../fixtures/templates.yml', __FILE__)).each do |item|
    info = item.last
    FakeTemplates  << Struct::FakeTemplate.new(info["name"],
                                               info["basesystem"],
                                               info["appliance_id"],
                                               info["description"])
  end
  FakeTemplates.freeze
end

class CliTest < Test::Unit::TestCase

  context "Run with FakeFS" do

    setup do
      FakeFS.activate!
    end

    teardown do
      FakeFS.deactivate!
    end

    context "no parameter passed" do

      setup do
        @out = capture(:stdout) { Dister::Cli.start() }
      end

      should "show help message" do
        assert @out.include?("Tasks:")
      end

    end

    context "wrong param" do

      setup do
        @out = capture(:stdout) do
          @err = capture(:stderr) { Dister::Cli.start(['foo']) }
        end
      end

      should "show help message" do
        assert_equal 'Could not find task "foo".', @err.chomp
        assert @out.empty?
      end

    end

    context "creating a new appliance" do

      setup do
        Dister::Core.any_instance.stubs(:templates).returns(FakeTemplates)
        basesystems = ["11.1", "SLED10_SP2", "SLES10_SP2", "SLED11", "SLES11",
                       "11.2", "SLES11_SP1", "SLED11_SP1", "11.3", "SLED10_SP3",
                       "SLES10_SP3", "SLES11_SP1_VMware"]
        Dister::Core.any_instance.stubs(:basesystems).returns(basesystems)
      end

      should "refuse invalid archs" do
        STDERR.stubs(:puts)
        assert_raise SystemExit do
          Dister::Cli.start(['create', 'foo','--arch', 'ppc'])
        end
      end

      should "accept valid archs" do
        Dister::Core.any_instance.expects(:create_appliance).returns(true)
        assert_nothing_raised do
          Dister::Cli.start(['create', 'foo','--arch', 'x86_64'])
        end
      end

      should "guess latest version of openSUSE if no base system is specified" do
        Dister::Core.any_instance.expects(:create_appliance).\
                                 with("foo", "JeOS", "11.3", "i686").\
                                 returns(true)
        assert_nothing_raised do
          Dister::Cli.start(['create', 'foo'])
        end
      end

      should "detect bad combination of template and basesystem" do
        STDERR.stubs(:puts)
        assert_raise(SystemExit) do
          Dister::Cli.start(['create', 'foo', "--template", "jeos",
                             "--basesystem", "SLES11_SP1_VMware"])
        end
      end

    end

    context "When executing 'dister bundle' it" do

      should 'package all required gems' do
        Dister::Core.any_instance.expects(:package_gems).once
        Dister::Core.any_instance.expects(:package_app).once
        Dister::Cli.start ['bundle']
      end

    end

  end

end
