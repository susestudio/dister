require 'fileutils'

module Dister
  class Options

    GLOBAL_PATH = "#{File.expand_path('~')}/.dister"
    LOCAL_PATH = "#{Dister::Core::APP_ROOT}/.dister/options.yml"

    # Read global and local option files.
    def initialize
      # Global options hold the user's credentials to access SUSE Studio.
      # They are stored inside the user's home directory.
      @global = read_options_from_file(GLOBAL_PATH)
      # Local options hold application specific data (e.g. appliance_id)
      # They are stored inside the application's root directory.
      @local = read_options_from_file(LOCAL_PATH)
    end

    # Returns a hash consisting of both global and local options.
    # All options can be read through this method.
    # NOTE: Local options override global options.
    def provide
      @global.merge(@local)
    end

    def method_missing(method, *args)
      method_name = method.to_s
      if (method_name =~ /=$/).nil?
        # getter
        provide[method_name]
      else
        # setter
        store(method_name[0..-2], args.first)
      end
    end

    # Stores a specified option_key inside its originating options file.
    def store(option_key, option_value)
      if determine_options_file(option_key) == 'local'
        @local[option_key] = option_value
        options_hash = @local
        file_path = LOCAL_PATH
      else
        @global[option_key] = option_value
        options_hash = @global
        file_path = GLOBAL_PATH
      end
      write_options_to_file(options_hash, file_path)
    end

    private

    # Reads from global or local options file and returns an options hash.
    def read_options_from_file(file_path)
      values_hash = YAML.load_file(file_path)
      # In the unlikely case that the options file is empty, return an empty hash.
      values_hash ? values_hash : {}
    rescue Errno::ENOENT
      # File does not exist.
      options_dir = File.dirname(file_path)
      FileUtils.mkdir_p(options_dir) unless File.directory?(options_dir)
      File.new(file_path, 'w')
      retry
    end

    # Writes an options_hash back to a specified options file.
    def write_options_to_file(options_hash, file_path)
      File.open(file_path, 'w') do |out|
        YAML.dump(options_hash, out)
      end
    end

    # Determines to which file an option gets written.
    def determine_options_file(option_key)
      # Search in local options first, since they override global options.
      case option_key
        when @local.keys.include?(option_key) : 'local'
        when @global.keys.include?(option_key) : 'global'
        else
          if ['username', 'api_key'].include?(option_key)
            # Credentials are stored globally per default.
            'global'
          else
            # New options get stored locally.
            'local'
          end
      end
    end

  end

end
