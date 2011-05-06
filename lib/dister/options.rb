require 'fileutils'

module Dister

  # Class for handling user- and application-specific settings
  class Options

    # Default API path, used unless a custom path is specified
    SUSE_STUDIO_DOT_COM_API_PATH = 'https://susestudio.com/api/v2/user'
    # Path to global (per-user) options file
    GLOBAL_PATH = "#{File.expand_path('~')}/.dister"
    # Path to app-specific options file
    LOCAL_PATH = "#{Dister::Core::APP_ROOT}/.dister/options.yml"

    attr_reader :use_only_local

    # Read options from file.
    #
    # @param [Boolean] use_only_local Use only local options?
    def initialize use_only_local=false
      @use_only_local = use_only_local
      reload
    end

    # Provides setter and getter for all options.
    def method_missing(method, *args)
      method_name = method.to_s
      if (method_name =~ /=$/).nil?
        # Getter
        provide[method_name]
      else
        # Setter
        store(method_name[0..-2], args.first)
      end
    end

    # Read +@global+ and +@local+ option files. Run this method if their
    # contents has changed.
    def reload
      if @use_only_local
        @global = {}
      else
        # Global options hold the user's credentials to access SUSE Studio.
        # They are stored inside the user's home directory.
        @global = read_options_from_file(GLOBAL_PATH)

        # make sure the default api path is available
        unless @global.has_key? 'api_path'
          @global['api_path'] = SUSE_STUDIO_DOT_COM_API_PATH
        end
      end
      # Local options hold application specific data (e.g. appliance_id)
      # They are stored inside the application's root directory.
      @local = read_options_from_file(LOCAL_PATH)
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
      return 'local' if @use_only_local

      # Search in local options first, since they override global options.
      case option_key
        when @local.keys.include?(option_key) then 'local'
        when @global.keys.include?(option_key) then 'global'
        else
          if %w(username api_key api_path).include?(option_key)
            # Credentials are stored globally per default.
            'global'
          else
            # New options get stored locally.
            'local'
          end
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

    # Returns a hash consisting of both global and local options.
    # All options can be read through this method.
    # NOTE: Local options override global options.
    #
    # @return [Hash] a hash consisting of both global and local options
    def provide
      @global.merge(@local)
    end

  end

end
