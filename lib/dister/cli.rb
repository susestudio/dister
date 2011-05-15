module Dister

  # This is the public facing command line interface which is available through
  # the +dister+ command line tool. Use +dister --help+ for usage instructions.
  class Cli < Thor

    include Thor::Actions

    # NOTE: Some of Thor's actions require this method to be defined.
    # @return [String] Dister's root directory.
    def self.source_root
      File.expand_path('../../',__FILE__)
    end

    desc "version", "Show dister version"
    def version
      require "dister/version"
      puts "dister version #{Dister::VERSION}"
    end

    desc "config OPTION VALUE", "set OPTION value to VALUE"
    method_option :local,
      :type => :boolean, :default => false, :required => false
    def config option, value
      dister_options = Dister::Options.new(!options[:local].nil?)
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
      if basesystems.empty?
        STDERR.puts "No basesystem found, contact server administrator"
        exit 1
      end

      if options[:basesystem].nil?
        # attempt to find latest version of openSUSE
        basesystem = basesystems.find_all{|a| a =~ /\d+\.\d+/}.sort.last
        if basesystem.nil?
          # apparently this server doesn't offer openSUSE basesystem, so we
          # present the user with a menu with available choices
          basesystem = choose do |menu|
            menu.header = "Available base systems"
            menu.choices *basesystems
            menu.prompt = "Which base system do you want to use?"
          end
        end
      else
        basesystem = options[:basesystem]
      end
      ensure_valid_option basesystem, basesystems, "base system"
      # Create appliance and add patterns required to build native gems.
      @core.create_appliance(appliance_name, options[:template], basesystem, options[:arch])
    end

    desc "build", "Build the appliance."
    method_option :force, :type => :boolean, :default => false, :required => false
    def build
      access_core
      ensure_appliance_exists
      if @core.build options
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

    desc "testdrive", "Testdrive the appliance."
    def testdrive
      access_core
      ensure_appliance_exists
      ensure_build_exists
      @core.testdrive(@builds)
    end

    desc "format list|add|rm FORMAT", "Enables building of FORMAT"
    method_option :all, :type => :boolean, :default => false, :required => false
    def format(operation,format = nil)
      access_core
      ensure_valid_option operation, %w(add rm list), "operation"
      if operation == 'list'
        puts "Available formats:"
        puts VALID_FORMATS
      else
        existing_types = @core.options.build_types || []
        chosen_types = case operation
          when "add"
            ensure_valid_option format, VALID_FORMATS, "format"
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
      @core.package_config_files
      # Package app last, since it will tarball the application including all gems.
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

    desc "package add|rm PACKAGE [PACKAGE, ...]", "Add/remove PACKAGE to the appliance"
    def package operation, *package
      access_core
      valid_operations = %w(add rm)
      ensure_valid_option operation, valid_operations, "operation"
      case operation
      when "add"
        package.each do |p|
          @core.add_package p
        end
      when "rm"
        package.each do |p|
          @core.rm_package p
        end
      end
      @core.verify_status
      puts "Done."
    end

    desc "info", "Show some useful information about the appliance"
    def info
      access_core
      app = Utils::execute_printing_progress "Contacting SUSE Studio" do
        @core.appliance
      end
      puts "Name: #{app.name}"
      puts "Based on: #{app.parent.name}"
      if app.builds.empty?
        puts "No builds yet."
      else
        puts "Builds:"
        app.builds.each do |b|
          puts "  - #{b.image_type}, version #{b.version}"
        end
      end
      puts "Edit url: #{app.edit_url}"
    end

    private

    # Convenience method to reduce duplicity and improve readability.
    # Sets @core
    def access_core
      @core ||= Core.new
    end

    # Checks whether an appliance already exists (invokes :create if not).
    def ensure_appliance_exists
      if @core.appliance.nil?
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
