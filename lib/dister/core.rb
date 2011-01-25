module Dister

  class Core

    API_PATH = 'https://susestudio.com/api/v1/user'

    # Connect to SUSE Studio and verify credentials.
    # Sets @connection for further use.
    def initialize
      @global_options ||= Options.new
      credentials = @global_options.credentials
      @connection = StudioApi::Connection.new(
        credentials['username'],
        credentials['api_key'],
        API_PATH
      )
      # Try the connection once to determine whether credentials are correct.
      @connection.api_version
      StudioApi::Util.configure_studio_connection @connection
      true
    rescue ActiveResource::UnauthorizedAccess
      puts 'A connection to SUSE Studio could not be established.'
      keep_trying = Thor::Shell::Basic.new.ask(
        'Would you like to re-enter your credentials and try again? (y/n)'
      )
      if keep_trying == 'y'
        @global_options.update_credentials
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
        #TODO store id inside a yml file
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
  end

end
