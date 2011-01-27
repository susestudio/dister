module Dister

  class Core

    attr_reader :options, :shell

    APP_ROOT = File.expand_path('.')

    # Connect to SUSE Studio and verify the user's credentials.
    # Sets @dister_options, @shell and @connection for further use.
    def initialize
      @options ||= Options.new
      @shell = Thor::Shell::Basic.new
      @connection = StudioApi::Connection.new(
        @options.username,
        @options.api_key,
        @options.api_path
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
        @options.appliance_id = app.id
      end
      self.add_package "devel_C_C++"
      self.add_package "devel_ruby"
      # TODO: Install bundler!
    end

    def build
      verify_status
      #TODO: build using another format
      build = StudioApi::RunningBuild.create(
        :appliance_id => @options.appliance_id,
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

    # Returns an app's appliance (or nil if none exist).
    def appliance
      appliance_id = self.options.appliance_id
      return nil if appliance_id.nil?
      StudioApi::Appliance.find(appliance_id.to_i)
    rescue ActiveResource::BadRequest
      self.options.appliance = nil
      nil
    end

    def builds
      StudioApi::Build.find(:all, :params => {:appliance_id => @options.appliance_id})
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
    def file_upload filename, upload_options={}
      if File.exists? filename
        File.open(filename) do |file|
          StudioApi::File.upload file, @options.appliance_id, upload_options
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

    # Uploads all gems and the app tarball to the appliance.
    def upload_bundled_files
      # Collect data.
      cache_dir = "#{APP_ROOT}/vendor/cache"
      gem_files = (Dir.new(cache_dir).entries - ['.', '..']).collect do |file_name|
        "#{cache_dir}/#{file_name}"
      end
      remote_path = "/srv/www/#{APP_ROOT.split(/(\/|\\)/).last}/upload"
      upload_options = {
        :path => remote_path,
        :owner => 'root',
        :group => 'root'
      }
      # Delete obsolete files.
      StudioApi::File.find(:all, :params => {
        :appliance_id => self.options.appliance_id
      }).select{|file| file.path == remote_path}.each(&:destroy)
      # Upload new files.
      (gem_files + ["#{APP_ROOT}/.dister/application.tar.gz"]).each do |file_name|
        if self.file_upload(file_name, upload_options)
          puts "Successfully uploaded '#{file_name}'."
        else
          STDERR.puts "Upload of '#{file_name}' failed. Exiting."
          break
        end
      end
    end

    def add_package package
      puts "Looking for #{package}"
      appliance = StudioApi::Appliance.find @options.appliance_id
      result = appliance.search_software(package) #.find { |s| s.name == package }
      #TODO: better handling
      #Blocked by bnc#
      if result.empty? #it is not found in available repos
        puts "'#{package}' has not been found in the repositories currently "\
             "added to your appliance."
        keep_trying = @shell.ask('Would you like to search for this package '\
                                'inside other repositories? (y/n)')
        if keep_trying == 'y'
          results = appliance.search_software(package, :all_repos => true)\
                             .find_all { |s| s.name == package }
          if results.empty?
            puts "Cannot find #{package}, please look at this page: "
            puts URI.encode "http://software.opensuse.org/search?p=1&baseproject=ALL&q=#{package}"
          else
            results.each do |r|
              puts r.inspect
            end
          end
        else
          exit 0
        end
        # add repo which contain samba
        #appliance.add_repository result.repository_id
      end
      appliance.add_package(package)
    end

    def rm_package package
    end

    # Make sure the appliance doesn't have conflicts.
    # In this case an error message is shown and the program halts.
    def verify_status
      appliance = StudioApi::Appliance.find @options.appliance_id
      if appliance.status.state != "ok"
         STDERR.puts "appliance is not OK - #{appliance.status.issues.inspect}"
         STDERR.puts "Visit #{appliance.edit_url} to manually fix the issue."
         exit 1
      end
    end


    def download(build_set)
      # Choose the build(s) to download.
      to_download = []
      if build_set.size == 1
        to_download << build_set.first
      else
        build_set.each_with_index do |build, index|
          puts "#{index+1}) #{build.to_s}"
        end
        puts "#{build_set.size+1}) All of them."
        puts "#{build_set.size+2}) None."
        begin
          choice = @shell.ask "Which appliance do you want to download? [1-#{build_set.size+1}]"
        end while (choice.to_i > (build_set.size+2))
        if choice.to_i == (build_set.size+2)
          # none selected
          exit 0
        elsif choice.to_i == (build_set.size+1)
          # all selected
          to_download = build_set
        else
          to_download << build_set[choice.to_i-1]
        end
      end
      # Download selected builds.
      to_download.each do |b|
        puts "Going to download #{b.to_s}"
        d = Downloader.new(b.download_url.sub("https:", "http:"), "Downloading", b.compressed_image_size.to_i)
        begin
          d.start
        rescue
          STDOUT.puts
          STDERR.puts
          STDERR.flush
          STDERR.puts $!
          exit 1
        end
      end
    end

    private

    # Updates a user's credentials and stores them inside the global options file.
    def update_credentials
      puts 'Please enter your SUSE Studio credentials (https://susestudio.com/user/show_api_key).'
      @options.username = @shell.ask("Username:\t")
      @options.api_key = @shell.ask("API key:\t")
    end

  end

end
