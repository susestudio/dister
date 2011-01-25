require File.expand_path('../test_helper', __FILE__)

class OptionsTest < Test::Unit::TestCase

  def save_credentials(credentials)
    FileUtils.mkdir_p(File.dirname(Dister::Options::GLOBAL_OPTIONS_PATH))
    File.open(Dister::Options::GLOBAL_OPTIONS_PATH, 'w') do |out|
      YAML.dump(credentials, out)
    end
  end

  context 'While initializing options it' do

    should 'read global options' do
      FakeFS do
        expected_credentials = {"username" => "flavio",
                                "api_key" => "dister"}
        save_credentials(expected_credentials)

        options = Dister::Options.new()
        assert_equal expected_credentials, options.credentials
      end
    end

    should 'ensure the existence of a global config file' do
      FakeFS do
        Dister::Options.new()
        assert File.exists? Dister::Options::GLOBAL_OPTIONS_PATH
      end
    end
  end

  context 'For existing options it' do

    setup do
      FakeFS.activate!
      @credentials = {'username' => 'foo', 'api_key' => 'bar'}
      save_credentials(@credentials)
      @global_options = Dister::Options.new
    end

    teardown do
      FakeFS.deactivate!
    end

    should 'show credentials' do
      assert_equal @credentials, @global_options.credentials
    end

    should 'allow to update credentials' do
      @global_options.stubs(:puts)
      Thor::Shell::Basic.any_instance.stubs(:ask).returns('foo')
      File.expects(:open).once.returns(true)
      new_credentials = @global_options.update_credentials
      assert_equal 'foo', new_credentials['username']
      assert_equal 'foo', new_credentials['api_key']
      assert_equal new_credentials, @global_options.credentials
    end

  end

end
