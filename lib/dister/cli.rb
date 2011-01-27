module Dister

  class Cli < Thor

    VALID_TEMPLATES = %w(JeOS Server X Gnome KDE)
    VALID_FOMATS = %w(oem vmx iso xen) #TODO: add other formats
    VALID_ARCHS = %w(i686 x86_64)

    include Thor::Actions

    # Returns Dister's root directory.
    # NOTE: Some of Thor's actions require this method to be defined.
    def self.source_root
      File.expand_path('../../',__FILE__)
    end

    desc "config OPTION VALUE", "set OPTION value to VALUE"
    method_option :global,
      :type => :boolean, :default => false, :required => false
    method_option :local,
      :type => :boolean, :default => false, :required => false
    def config option, value
      if options[:global] && options[:local]
        STDERR.puts "You cannot use the --global and --local switches at the same time"
        exit 1
      end

      dister_options = nil
      if options[:local]
        # use only local options
        dister_options = Dister::Options.new(true)
      else
        # use also global options
        dister_options = Dister::Options.new(false)
      end

      dister_options.send("#{option}=", value)
    end

    desc "create APPLIANCE_NAME", "create a new appliance named APPLIANCE_NAME."
    method_option :basesystem, :type => :string, :default => nil, :required => false
    method_option :template, :type => :string, :default => 'JeOS', :required => false
    method_option :arch, :type => :string, :default => 'i686', :required => false
    def create(appliance_name)
      # Check parameters.
      access_core
      ensure_valid_option options[:arch], VALID_ARCHS, "arch"
      ensure_valid_option options[:template], VALID_TEMPLATES, "template"
      basesystems = @core.basesystems
      basesystem = options[:basesystem] || basesystems.find_all{|a| a =~ /\d+\.\d+/}.sort.last
      ensure_valid_option basesystem, basesystems, "base system"
      # Create appliance and add patterns required to build native gems.
      @core.create_appliance(appliance_name, options[:template], basesystem, options[:arch])
    end

    desc "build", "Build the appliance."
    def build
      access_core
      ensure_appliance_exists
      if @core.build
        puts "Appliance successfully built."
      else
        puts "Build failed."
      end
    end

    desc "download", "Download the appliance."
    def download
      access_core
      ensure_appliance_exists
      ensure_build_exists
      @core.download(@builds)
    end

    desc "format OPERATION FORMAT", "Enables building of FORMAT"
    method_option :all, :type => :boolean, :default => false, :required => false
    def format(operation,format = nil)
      access_core
      ensure_valid_option operation, %w(add rm list), "operation"
      if operation == 'list' and options[:all]
        puts "Available formats:"
        puts VALID_FOMATS
      else
        existing_types = @core.options.build_types || []
        chosen_types = case operation
          when "add"
            ensure_valid_option format, VALID_FOMATS, "format"
            @core.options.build_types = (existing_types + [format]).uniq
          when "rm"
            @core.options.build_types = (existing_types - [format])
          else
            existing_types
          end
        puts "Chosen formats:"
        puts chosen_types
      end
    end

    desc "templates", "List all the templates available on SUSE Studio."
    def templates
      puts VALID_TEMPLATES.sort
    end

    desc "basesystems", "List all the base systems available on SUSE Studio."
    def basesystems
      access_core
      puts @core.basesystems.sort
    end

    desc "bundle", "Bundles the application and all required gems."
    def bundle
      access_core
      @core.package_gems
      @core.package_app
    end

    desc 'push', 'Pushes all required gems and the application tarball to SUSE Studio.'
    def push
      access_core
      # Always call 'bundle' to ensure we got the latest version bundled.
      invoke :bundle
      ensure_appliance_exists
      @core.upload_bundled_files
    end

    desc "package OPERATION PACKAGE_NAME", "Add/remove PACKAGE_NAME to the appliance"
    def package operation, package
      access_core
      valid_operations = %w(add rm)
      ensure_valid_option operation, valid_operations, "operation"
      case operation
      when "add"
        @core.add_package package
      when "rm"
        @core.rm_package package
      end
      @core.verify_status
      puts "Done."
    end

    private

    # Convenience method to reduce duplicity and improve readability.
    # Sets @core
    def access_core
      @core ||= Core.new
    end

    # Checks whether an appliance already exists (invokes :create if not).
    def ensure_appliance_exists
      if @core.options.appliance_id.nil?
        appliance_id = @core.shell.ask('Please provide a name for your appliance:')
        invoke :create, [appliance_id]
        @core.options.reload
      end
    end

    # Checks whether there is at least one existing build (invokes :build if not).
    def ensure_build_exists
      @builds = @core.builds
      if @builds.empty?
        invoke :build
        @builds = @core.builds
        @core.options.reload
      end
    end

    # Ensures actual_value is allowed. If not prints an error message to
    # stderr and exits
    def ensure_valid_option actual_value, allowed_values, option_name
      if allowed_values.find{|v| v.downcase == actual_value.downcase}.nil?
        STDERR.puts "#{actual_value} is not a valid value for #{option_name}"
        STDERR.puts "Valid values are: #{allowed_values.join(" ")}"
        exit 1
      end
    end

  end

end
