module Dister
  class Core
    def self.options
      # NOTE: Since we're so far only using this once to establish a connection,
      # thats just fine. If we use it more often, store the info in a constant.
      YAML.load_file("#{File.expand_path('~')}/.dister/auth.yml")
    end

    # Connect to SUSE Studio and verify credentials.
    # Sets @connection for further use.
    def initialize
      begin
        @connection = StudioApi::Connection.new(
          Core.options['username'],
          Core.options['api_key'],
          'https://susestudio.com/api/v1/user'
        )
        @connection.api_version
        StudioApi::Util.configure_studio_connection @connection
        true
      rescue ActiveResource::UnauthorizedAccess
        @connection = nil
        false
      end
    end

    # Creates a new appliance.
    # Returns the new appliance.
    def create_appliance(name, template, basesystem, arch)
      match = check_template_and_basesystem_availability(template, basesystem)
      if match.nil?
        exit 1
      else
        StudioApi::Appliance.clone match.appliance_id, :name => name,
                                   :arch => arch
      end
    end

    def templates
      StudioApi::TemplateSet.find(:all).find {|s| s.name == "default" }.template
    end

    def basesystems
      b = []
      templates.each do |t|
        b << t.basesystem unless b.include? t.basesystem
      end
      b
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
