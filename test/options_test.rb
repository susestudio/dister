require File.expand_path('../test_helper', __FILE__)

class OptionsTest < Test::Unit::TestCase

  # Small helper method to use FakeFS for storing options.
  def save_options(options_map, options_type)
    options_path = case options_type
      when :local : Dister::Options::LOCAL_PATH
      when :global : Dister::Options::GLOBAL_PATH
      else
        raise "Invalid options type '#{options_type}'."
    end
    FileUtils.mkdir_p(File.dirname(options_path))
    File.open(options_path, 'w') do |out|
      YAML.dump(options_map, out)
    end
  end

  context 'While initializing options it' do
    setup do
      FakeFS.activate!
    end

    teardown do
      FakeFS.deactivate!
    end

    should 'read global and local options' do
      global_options = {'username' => 'foo', 'api_key' => 'bar'}
      save_options(global_options, :global)
      local_options = {'appliance_id' => '1'}
      save_options(local_options, :local)
      assert_equal global_options.merge(local_options), Dister::Options.new.provide
    end

    should 'ensure the existence of a global and a local config file' do
      Dister::Options.new
      assert File.exists? Dister::Options::GLOBAL_PATH
      assert File.exists? Dister::Options::LOCAL_PATH
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

  context "Options entries are mapped to class methods" do
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

    should "read existing options" do
      [@global, @local].each do |options_map|
        options_map.each do |key, value|
          assert_nothing_raised do
            assert_equal value, @dister_options.send(key)
          end
        end
      end

      assert_equal "foo", @dister_options.username
    end

    should "handle non existing options" do
      assert_nothing_raised do
        assert_equal nil, @dister_options.a_new_option
      end
    end

    context "assignment operator" do
      should "update existing options" do
        [@global, @local].each do |options_map|
          options_map.each do |key, value|
            assert_nothing_raised do
              @dister_options.send("#{key}=","#{value} NEW")
              assert_equal "#{value} NEW", @dister_options.send(key)
            end
          end
        end
      end

      should "create a new entry if it doesn't exist" do
        @dister_options.a_new_option = "NEWBIE!"
        assert_equal "NEWBIE!", @dister_options.a_new_option
      end
    end
  end
end
