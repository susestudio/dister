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

  context "create" do
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

