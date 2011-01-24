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
end

