require File.expand_path('../test_helper', __FILE__)

class OptionsTest < Test::Unit::TestCase

  context 'while initializing options it' do

    should 'read global options' do
      YAML.expects(:load_file).once.returns({:foo => 'bar'})
      Dister::Options.new()
    end

    should 'ask for credentials' do
      YAML.expects(:load_file).once.raises(Errno::ENOENT)
      File.expects(:new).once.returns(true)
      Thor::Shell::Basic.any_instance.stubs(:ask).returns('foo')
      File.expects(:open).once.returns(true)
      @output = capture(:stdout) { Dister::Options.new() }
      assert @output.include?('credentials')
    end
  end

  context 'for existing options it' do

    setup do
      @credentials = {:username => 'foo', :api_key => 'bar'}
      YAML.stubs(:load_file).returns(@credentials)
      @global_options = Dister::Options.new
    end

    # FIXME:
    # Don't know why this won't work. @global_options_hash is set correctly.
    # #<Dister::Options:0x7ff71bf22640 @global_options_hash={:username=>"foo", :api_key=>"bar"}>
    # @global_options.credentials => {"api_key"=>nil, "username"=>nil}
    # should 'show credentials' do
      #
      # assert_equal @credentials, @global_options.credentials
    # end

    should 'allow to update credentials' do
      Thor::Shell::Basic.any_instance.stubs(:ask).returns('foo')
      File.expects(:open).once.returns(true)
      new_credentials = @global_options.update_credentials
      assert_equal 'foo', new_credentials['username']
      assert_equal 'foo', new_credentials['api_key']
      assert_equal new_credentials, @global_options.credentials
    end

  end

end