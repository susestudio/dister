require File.expand_path('../test_helper', __FILE__)

class OptionsTest < Test::Unit::TestCase

  def save_credentials(credentials)
    FileUtils.mkdir_p(File.dirname(Dister::Options::GLOBAL_OPTIONS_PATH))
    File.open(Dister::Options::GLOBAL_OPTIONS_PATH, 'w') do |out|
      YAML.dump(credentials, out)
    end
  end

  context 'While initializing options it' do

    should 'read global and local options' do
      YAML.expects(:load_file).times(2).returns({:foo => 'bar'})
      Dister::Options.new()
    end

    should 'ensure the existence of a global and a local config file' do
      YAML.stubs(:load_file).raises(
        Errno::ENOENT
      ).then.returns(
        false
      ).then.raises(
        Errno::ENOENT
      ).then.returns(
        false
      )
      File.expects(:new).times(2).returns(true)
      Dister::Options.new()
    end

  end

  context 'For existing options it' do

    setup do
      @global = {'username' => 'foo', 'api_key' => 'bar'}
      @local = {'appliance_id' => '0'}
      YAML.stubs(:load_file).returns(@global).then.returns(@local)
      @dister_options = Dister::Options.new
    end

    should 'provide global and local options' do
      assert_equal @global.merge(@local), @dister_options.provide
    end

    should 'allow to store global and local options' do
      File.expects(:open).times(2).returns(true)
      assert @dister_options.store('appliance_id', '1')
      assert_equal '1', @dister_options.provide['appliance_id']
      assert @dister_options.store('username', 'bar')
      assert_equal 'bar', @dister_options.provide['username']
    end

  end

end
