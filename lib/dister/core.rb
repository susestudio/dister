require 'digest/md5'
require 'erb'

module Dister

  class Core

    attr_reader :options, :shell

    APP_ROOT = File.expand_path('.')

    # Connect to SUSE Studio and verify the user's credentials.
    # Sets @options, @shell and @connection for further use.
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

      # Ensure app_name is stored for further use.
      if @options.app_name.nil?
        @options.app_name = APP_ROOT.split(/(\/|\\)/).last
      end

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
      exit 1 if match.nil?

      @db_adapter = get_db_adapter
      app = Utils::execute_printing_progress "Cloning appliance" do
        StudioApi::Appliance.clone(match.appliance_id, {:name => name,
                                                        :arch => arch})
      end
      @options.appliance_id = app.id
      ensure_devel_languages_ruby_extensions_repo_is_added
      self.add_package "devel_C_C++"
      self.add_package "devel_ruby"
      self.add_package 'rubygem-bundler'
      self.add_package 'rubygem-passenger-apache2'
      @db_adapter.packages.each do |p|
        self.add_package p
      end

      Utils::execute_printing_progress "Uploading build scripts" do
        upload_configurations_scripts
      end
      puts "SUSE Studio appliance successfull created:"
      puts "  #{app.edit_url}"
      app
    end

    def build
      verify_status
      #TODO: build using another format
      build = StudioApi::RunningBuild.create(
        :appliance_id => @options.appliance_id,
        :image_type => "oem"
      )

      build.reload
      if build.state == "queued"
        puts "Your build is queued. It will be automatically processed by "\
             "SUSE Studio. You can keep waiting or you can exit from dister."
        puts "Exiting from dister won't remove your build from the queue."
        shell = Thor::Shell::Basic.new
        keep_waiting = @shell.ask('Do you want to keep waiting (y/n)')
        if keep_waiting == 'n'
          exit 0
        end

        Utils::execute_printing_progress "Build queued..." do
          while build.state == 'queued' do
            sleep 5
            build.reload
          end
        end
      end

      # build is no longer queued
      pbar = ProgressBar.new "Building", 100

      while not ['finished', 'error', 'failed', 'cancelled'].include?(build.state)
        pbar.set build.percent.to_i
        sleep 5
        build.reload
      end
      pbar.finish
      build.state == 'finished'
    end

    # Returns an app's appliance (or nil if none exist).
    def appliance
      if @appliance.nil?
        begin
          appliance_id = self.options.appliance_id
          return nil if appliance_id.nil?
          @appliance = StudioApi::Appliance.find(appliance_id.to_i)
        rescue ActiveResource::BadRequest
          self.options.appliance_id = nil
          nil
        end
      else
        @appliance
      end
    end

    def builds
      StudioApi::Build.find(:all, :params => {:appliance_id => @options.appliance_id})
    end

    def templates
      reply = StudioApi::TemplateSet.find(:first, :conditions => {:name => "default"})
      if reply.nil?
        STDERR.puts "There is no default template set named 'default'"
        STDERR.puts "Please contact SUSE Studio admin"
        exit 1
      else
        return reply.template
      end
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
        # Delete existing (obsolete) file.
        StudioApi::File.find(:all, :params => {
          :appliance_id => self.options.appliance_id
        }).select { |file|
          file.path == (upload_options[:path] || '/') and file.filename == File.basename(filename)
        }.each(&:destroy)
        # Upload new file.
        message =  "Uploading #{filename} "
        message += "(#{Utils.readable_file_size(File.size(filename),2)})"
        Utils::execute_printing_progress message do
          File.open(filename) do |file|
            StudioApi::File.upload file, @options.appliance_id, upload_options
          end
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
      package = ".dister/#{@options.app_name}_application.tar.gz"
      system "rm #{package}" if File.exists?(package)
      system "tar -czf .dister/#{@options.app_name}_application.tar.gz ../#{@options.app_name}/ --exclude=.dister &> /dev/null"
      puts "Done!"
    end

    # Creates all relevant config files (e.g. apache.conf) for the appliance.
    def package_config_files
      filename = File.expand_path('../../templates/passenger.erb', __FILE__)
      erb = ERB.new(File.read(filename))
      config_content = erb.result(binding)

      config_path = "#{APP_ROOT}/.dister/#{@options.app_name}_apache.conf"
      FileUtils.rm(config_path, :force => true)
      File.open(config_path, 'w') do |config_file|
        config_file.write(config_content)
      end
      
      @db_adapter = get_db_adapter
      create_db_user_file = "#{APP_ROOT}/.dister/create_db_user.sql"
      FileUtils.rm(create_db_user_file, :force => true)
      File.open(create_db_user_file, 'w') do |file|
        file.write(@db_adapter.create_user_cmd)
      end
    end

    # Uploads the app tarball and the config file to the appliance.
    def upload_bundled_files
      upload_options = {:path => "/srv/www", :owner => 'root', :group => 'root'}
      # Upload tarball.
      self.file_upload("#{APP_ROOT}/.dister/#{@options.app_name}_application.tar.gz", upload_options)
      # Upload config files to separate location.
      upload_options[:path] = "/etc/apache2/vhosts.d"
      self.file_upload("#{APP_ROOT}/.dister/#{@options.app_name}_apache.conf", upload_options)
      # Upload db related files to separate location.
      upload_options[:path] = "/root"
      self.file_upload("#{APP_ROOT}/.dister/create_db_user.sql", upload_options)
    end

    def add_package package
      appliance_basesystem = appliance.basesystem
      result = appliance.search_software(package)#.find{|s| s.name == package }
      #TODO: better handling
      #Blocked by bnc#
      if result.empty? #it is not found in available repos
        puts "'#{package}' has not been found in the repositories currently "\
             "added to your appliance."
        keep_trying = @shell.ask('Would you like to search for this package '\
                                'inside other repositories? (y/n)')
        if keep_trying == 'y'
          matches = appliance.search_software(package, :all_repos => true)\
                             .find_all { |s| s.name == package }
          repositories = matches.map do |r|
            StudioApi::Repository.find r.repository_id
          end.find_all{|r| r.base_system == appliance_basesystem}

          if repositories.empty?
            puts "Cannot find #{package}, please look at this page: "
            puts URI.encode "http://software.opensuse.org/search?p=1&"\
                            "baseproject=ALL&q=#{package}"
          else
            puts "Package #{package} can be installed from one of the "\
                 "following repositories:"
            repositories.each_with_index do |repo, index|
              puts "#{index+1} - #{repo.name} (#{repo.base_url})"
            end
            puts "#{repositories.size+1} - None of them."
            begin
              choice = @shell.ask("Which repo do you want to use? "\
                                  "[1-#{repositories.size+1}]")
            end while (choice.to_i > (repositories.size+1))
            if (choice.to_i == (repositories.size+1))
              abort("Package not added.")
            else
              repo_id = repositories[choice.to_i-1].id
            end
            appliance.add_repository repo_id
          end
        else
          exit 0
        end
        # add repo which contain samba
        #appliance.add_repository result.repository_id
      end
      Utils::execute_printing_progress "Adding #{package} package" do
        appliance.add_package(package)
      end
    end

    def rm_package package
      Utils::execute_printing_progress "Removing #{package} package" do
        appliance.remove_package(package)
      end
    end

    # Uploads our configuration scripts
    def upload_configurations_scripts
      rails_root = "/srv/www/#{@options.app_name}"

      filename = File.expand_path('../../templates/boot_script.erb', __FILE__)
      erb = ERB.new(File.read(filename))
      boot_script = erb.result(binding)

      filename = File.expand_path('../../templates/build_script.erb', __FILE__)
      erb = ERB.new(File.read(filename))
      build_script = erb.result(binding)

      conf = appliance.configuration
      conf.scripts.boot.script = boot_script
      conf.scripts.boot.enabled = true

      conf.scripts.build.script = build_script
      conf.scripts.build.enabled = true
      conf.save
      true
    end

    # Asks Studio to mirror a repository.
    # Returns a StudioApi::Repository object
    def import_repository url, name
      StudioApi::Repository.import url, name
    end

    def ensure_devel_languages_ruby_extensions_repo_is_added
      name = "devel:language:ruby:extensions"
      url = "http://download.opensuse.org/repositories/devel:/languages:/ruby:/extensions/"

      case appliance.basesystem
      when "11.1"
        url += "openSUSE_11.1"
        name += " 11.1"
      when "11.2"
        url += "openSUSE_11.2"
        name += " 11.2"
      when "11.3"
        url += "openSUSE_11.3"
        name += " 11.3"
      when "SLED10_SP2", "SLED10_SP3", "SLES10_SP2", "SLES10_SP3"
        url += "SLE_10/"
        name += " SLE10"
      when "SLED11", "SLES11"
        url += "SLE_11"
        name += " SLE 11"
      when "SLED11_SP1", "SLES11_SP1", "SLES11_SP1_VMware"
        url += "SLE_11_SP1"
        name += " SLE11 SP1"
      else
        STDERR.puts "#{appliance.basesystem}: unknown base system"
        exit 1
      end

      Utils::execute_printing_progress "Adding #{name} repository" do
        repos = StudioApi::Repository.find(:all, :params => {:filter => url.downcase})
        if repos.size > 0
          repo = repos.first
        else
          repo = import_repository url, name
        end
        appliance.add_repository repo.id
      end
    end

    # Make sure the appliance doesn't have conflicts.
    # In this case an error message is shown and the program halts.
    def verify_status
      Utils::execute_printing_progress "Verifying appliance status" do
        if appliance.status.state != "ok"
           message = "Appliance is not OK - #{appliance.status.issues.inspect}"
           message += "\nVisit #{appliance.edit_url} to manually fix the issue."
           raise message
        end
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
        d = Downloader.new(b.download_url.sub("https:", "http:"),
                           "Downloading", b.compressed_image_size.to_i)
        if File.exists? d.filename
          overwrite = @shell.ask("Do you want to overwrite file #{d.filename}? (y/n)")
          exit 0 if overwrite == 'n'
        end
        begin
          d.start
          execute_printing_progress "Calculating md5sum" do
            Digest::MD5.file d.filename
            raise "digest check not passed" if digest.to_s != b.checksum.md5
          end
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

    def get_db_adapter
      db_config_file = "#{APP_ROOT}/config/database.yml"
      if !File.exists?(db_config_file)
        STDERR.puts "Cannot find #{db_config_file}."
        exit 1
      end
      @db_adapter ||= Dister::DbAdapter.new db_config_file
    end
  end
end
