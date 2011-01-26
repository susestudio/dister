module Dister

  class Core

    API_PATH = 'https://susestudio.com/api/v1/user'
    APP_ROOT = File.expand_path('.')

    # Connect to SUSE Studio and verify the user's credentials.
    # Sets @dister_options, @shell and @connection for further use.
    def initialize
      @dister_options ||= Options.new
      options_hash = @dister_options.provide
      @shell = Thor::Shell::Basic.new
      @connection = StudioApi::Connection.new(
        options_hash['username'],
        options_hash['api_key'],
        API_PATH
      )
      # Try the connection once to determine whether credentials are correct.
      @connection.api_version
      StudioApi::Util.configure_studio_connection @connection
      true
    rescue ActiveResource::UnauthorizedAccess
      puts 'A connection to SUSE Studio could not be established.'
      keep_trying = @shell.ask(
        'Would you like to re-enter your credentials and try again? (y/n)'
      )
      if keep_trying == 'y'
        update_credentials
        retry
      else
        abort('Exiting dister.')
      end
    end

    # Gets currently set options.
    def options
      @dister_options.provide
    end

    # Creates a new appliance.
    # Returns the new appliance.
    def create_appliance(name, template, basesystem, arch)
      match = check_template_and_basesystem_availability(template, basesystem)
      if match.nil?
        exit 1
      else
        app = StudioApi::Appliance.clone(
          match.appliance_id, {:name => name, :arch => arch}
        )
        puts "SUSE Studio appliance successfull created:"
        puts "  #{app.edit_url}"
        @dister_options.store('appliance_id', app.id)
      end
    end

    def build appliance_id
      #TODO: build using another format
      build = StudioApi::RunningBuild.create(
        :appliance_id => appliance_id,
        :image_type => "oem"
      )
      pbar = ProgressBar.new "Building", 100

      build.reload
      while build.state != "finished"
        pbar.set build.percent.to_i
        sleep 5
        build.reload
      end
      pbar.finish
      #TODO: what happens if there's a build error?
      true
    end

    def builds appliance_id
      StudioApi::Build.find(:all, :params => {:appliance_id => appliance_id})
    end

    def templates
      StudioApi::TemplateSet.find(:first, :conditions => {:name => "default"}).template
    end

    def basesystems
      templates.collect(&:basesystem).uniq
    end

    def check_template_and_basesystem_availability template, basesystem
      available_templates = self.templates
      match = available_templates.find do |t|
        t.basesystem == basesystem && t.name.downcase.include?(template.downcase)
      end

      if match.nil?
        STDERR.puts "The #{basesystem} doesn't have the #{template} template."
        STDERR.puts "Available templates are:"
        available_templates.find_all do |t|
          t.basesystem.downcase == basesystem.downcase
        end.each do |t|
          STDERR.puts "  - #{t.name}"
        end
      end
      match
    end

    # Uploads a file identified by filename to a SuSE Studio Appliance
    # options is an hash. it can have the following keys:
    # - filename (optional) - The name of the file in the filesystem.
    # - path (optional) - The path where the file will be stored.
    # - owner (optional) - The owner of the file.
    # - group (optional) - The group of the file.
    # - permissions (optional) - The permissions of the file.
    # - enabled (optional) - Used to enable/disable this file for the builds.
    # - url (optional) - The url of the file to add from the internet (HTTP and FTP are supported) when using the web upload method
    # This method returns true if the file has been successfully uploaded
    def file_upload filename, appliance_id, options={}
      if File.exists? filename
        options[:appliance_id] = appliance_id
        File.open(filename) do |file|
          StudioApi::File.upload file, options
        end
        true
      else
        STDERR.puts "Cannot upload #{filename}, it doesn't exists."
        false
      end
    end

    # Use bundler to download and package all required gems for the app.
    def package_gems
      puts 'Packaging gems...'
      system "cd #{APP_ROOT}"
      system "rm -R vendor/cache" if File.exists?("#{APP_ROOT}/vendor/cache")
      system 'bundle package'
      puts "Done!"
    end

    # Creates a tarball that holds the application's source-files.
    # Previously packaged versions get overwritten.
    def package_app
      puts 'Packaging application...'
      system "cd #{APP_ROOT}"
      package = "./.dister/application.tar.gz"
      system "rm #{package}" if File.exists?(package)
      system "tar -czf #{package} . --exclude=.dister"
      puts "Done!"
    end
    
    def add_package appliance_id, package
    end

    def rm_package appliance_id, package
    end

    private

    # Updates a user's credentials and stores them inside the global options file.
    def update_credentials
      puts 'Please enter your SUSE Studio credentials (https://susestudio.com/user/show_api_key).'
      @dister_options.store('username', @shell.ask("Username:\t"))
      @dister_options.store('api_key', @shell.ask("API key:\t"))
    end

  end

end
