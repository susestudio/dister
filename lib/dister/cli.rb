module Dister

  class Cli < Thor

    VALID_TEMPLATES = %w(JeOS Server X Gnome KDE)
    VALID_FOMATS = %w(oem vmx iso xen) #TODO: add other formats

    include Thor::Actions

    # Returns Dister's root directory.
    # NOTE: Some of Thor's actions require this method to be defined.
    def self.source_root
      File.expand_path('../../',__FILE__)
    end

    desc "create APPLIANCE_NAME", "create a new appliance named APPLIANCE_NAME."
    method_option :basesystem,
      :type => :string, :default => nil, :required => false
    method_option :template,
      :type => :string, :default => 'JeOS', :required => false
    method_option :arch,
      :type => :string, :default => 'i686', :required => false
    def create(appliance_name)
      access_core
      allowed_archs = %w(i686 x86_64)
      ensure_valid_option options[:arch], allowed_archs, "arch"

      basesystems = @core.basesystems
      basesystem = options[:basesystem] || basesystems.find_all{|a| a =~ /\d+\.\d+/}.sort.last
      ensure_valid_option basesystem, basesystems, "base system"

      ensure_valid_option options[:template], VALID_TEMPLATES, "template"

      @core.create_appliance appliance_name, options[:template],
                            basesystem, options[:arch]

      # add patterns required to build native gems
      @core.add_package "devel_C_C++"
      @core.add_package "devel_ruby"

      # TODO: install bundler
    end

    desc "build", "Build the appliance."
    def build
      access_core
      ensure_appliance_exists
      @core.verify_status
      if @core.build
        puts "Appliance successfully built."
      else
        puts "Something went wrong."
      end
    end

    desc "download", "Download the appliance."
    def download
      access_core
      ensure_appliance_exists
      builds = @core.builds
      to_download = []
      if builds.size  == 0
        puts "There are no builds yet, se the build command."
      elsif builds.size == 1
        to_download << builds.first
      else
        builds.each_with_index do |build, index|
          puts "#{index+1}) #{build.to_s}"
        end
        puts "#{builds.size+1}) All of them."
        puts "#{builds.size+2}) None."

        begin
          puts "Which appliance do you want to download? [1-#{builds.size+1}]"
          choice = STDIN.gets.chomp
        end while (choice.to_i > (builds.size+2))

        if choice.to_i == (builds.size+2)
          # none selected
          exit 0
        elsif choice.to_i == (builds.size+1)
          # all selected
          to_download = builds
        else
          to_download << builds[choice.to_i-1]
        end

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
    end

    desc "format OPERATION FORMAT", "Enables building of FORMAT"
    method_option :all, :type => :boolean, :default => false,
                        :required => false
    def format(operation,format=nil)
      valid_operations = %w(add rm list)
      ensure_valid_option operation, valid_operations, "operation"
      case operation
      when "add"
        ensure_valid_option format, VALID_FOMATS, "format"
        #TODO: local options store format
      when "rm"
        #TODO: local options: remove format
      when "list"
        if options[:all]
          VALID_FOMATS.each do |f|
            puts "  #{f}"
          end
        else
          #TODO: local options: show enabled formats
        end
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
