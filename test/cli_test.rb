require File.expand_path('../test_helper', __FILE__)

class CliTest < Test::Unit::TestCase
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
      base_systems = ["11.1", "SLED10_SP2", "SLES10_SP2", "SLED11", "SLES11",
                      "11.2", "SLES11_SP1", "SLED11_SP1", "11.3", "SLED10_SP3",
                      "SLES10_SP3", "SLES11_SP1_VMware"]
      Dister::Core.any_instance.stubs(:base_systems).returns(base_systems)
    end

    should "refuse invalid archs" do
      assert_raise SystemExit do
        Dister::Cli.start(['create', 'foo','--arch', 'ppc'])
      end
    end

    should "accept valid archs" do
      assert_nothing_raised do
        Dister::Cli.start(['create', 'foo','--arch', 'x86_64'])
      end
    end
  end
end
