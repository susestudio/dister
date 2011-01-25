module Dister
  class Options

    GLOBAL_OPTIONS_PATH = "#{File.expand_path('~')}/.dister/options.yml"

    # On creating a new instance of Options, the first thing to do is to ensure,
    # that the user has submitted his credentials for SUSE Studio.
    def initialize
      # NOTE: Since we're so far only reading this file once to establish a
      # connection, that's just fine. If we end up needing it to use it more
      # often, store the info in a constant.
      @global_options_hash = YAML.load_file(GLOBAL_OPTIONS_PATH)
      # In the unlikely case that the options file is empty, return an empty hash.
      @global_options_hash = {} unless @global_options_hash
    rescue Errno::ENOENT
      # File does not exist.
      global_options_dir = File.dirname(GLOBAL_OPTIONS_PATH)
      Dir.mkdir(global_options_dir) unless File.directory?(global_options_dir)
      File.new(GLOBAL_OPTIONS_PATH, 'w')
      update_credentials
    end

    # Picks credentials from @global_options.
    def credentials
      {
        'username' => @global_options_hash['username'],
        'api_key' => @global_options_hash['api_key']
      }
    end

    # Updates a user's credentials and stores them inside the global options file.
    def update_credentials
      puts 'Please enter your SUSE Studio credentials (https://susestudio.com/user/show_api_key).'
      shell = Thor::Shell::Basic.new
      @global_options_hash = {
        'username' => shell.ask("Username:\t"),
        'api_key' => shell.ask("API key:\t")
      }
      File.open(GLOBAL_OPTIONS_PATH, 'w') do |out|
        YAML.dump(@global_options_hash, out)
      end
      @global_options_hash
    end

  end
end
