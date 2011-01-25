require File.expand_path('../test_helper', __FILE__)

class OptionsTest < Test::Unit::TestCase

  context 'While initializing options it' do

    should 'read global options' do
      YAML.expects(:load_file).once.returns({:foo => 'bar'})
      Dister::Options.new()
    end

    should 'ensure the existence of a global config file' do
      YAML.stubs(:load_file).raises(Errno::ENOENT).then.returns(false)
      File.expects(:new).once.returns(true)
      Dister::Options.new()
    end
  end

  context 'For existing options it' do

    setup do
      @credentials = {'username' => 'foo', 'api_key' => 'bar'}
      YAML.stubs(:load_file).returns(@credentials)
      @global_options = Dister::Options.new
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