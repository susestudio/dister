require File.expand_path('../test_helper', __FILE__)

class OptionsTest < Test::Unit::TestCase

  # Small helper method to use FakeFS for storing options.
  def save_options(options_hash, options_type)
    options_path = case options_type
      when :local : Dister::Options::LOCAL_PATH
      when :global : Dister::Options::GLOBAL_PATH
      else
        raise "Invalid options type '#{options_type}'."
    end
    FileUtils.mkdir_p(File.dirname(options_path))
    File.open(options_path, 'w') do |out|
      YAML.dump(options_hash, out)
    end
  end

  context 'While initializing options it' do

    should 'read global and local options' do
      FakeFS do
        global_options = {'username' => 'foo', 'api_key' => 'bar'}
        save_options(global_options, :global)
        local_options = {'appliance_id' => '1'}
        save_options(local_options, :local)
        assert_equal global_options.merge(local_options), Dister::Options.new.provide
      end
    end

    should 'ensure the existence of a global and a local config file' do
      FakeFS do
        Dister::Options.new
        assert File.exists? Dister::Options::GLOBAL_PATH
        assert File.exists? Dister::Options::LOCAL_PATH
      end
    end

  end

  context 'For existing options it' do

    setup do
      FakeFS.activate!
      @global = {'username' => 'foo', 'api_key' => 'bar'}
      @local = {'appliance_id' => '0'}
      save_options(@global, :global)
      save_options(@local, :local)
      @dister_options = Dister::Options.new
    end

    teardown do
      FakeFS.deactivate!
    end

    should 'provide global and local options' do
      assert_equal @global.merge(@local), @dister_options.provide
    end

    should 'allow to store global and local options' do
      assert @dister_options.store('appliance_id', '1')
      assert_equal '1', @dister_options.provide['appliance_id']
      assert @dister_options.store('username', 'bar')
      assert_equal 'bar', @dister_options.provide['username']
    end

  end

end
