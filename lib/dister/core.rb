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
        true
      rescue ActiveResource::UnauthorizedAccess
        @connection = nil
        false
      end
    end

    # Creates a new appliance.
    # Returns the new appliance.
    def create_appliance(name, template, arch)
      templates = StudioApi::TemplateSet.find(:all).find {|s| s.name == "default" }.template
      template = templates.find { |t| t.name == "SLED 11 SP1, KDE 4 desktop" }
      StudioApi::Appliance.clone template.appliance_id,
                                 :name => name,
                                 :arch => arch
    end

    def list_templates
      templates = StudioApi::TemplateSet.find(:all).find {|s| s.name == "default" }.template
      templates.each do |t|
        puts t.inspect
      end
    end

    def base_systems
      b = []
      StudioApi::TemplateSet.find(:all).find {|s| s.name == "default" }.template.each do |t|
        b << t.basesystem unless b.include? t.basesystem
      end
      puts b.inspect
      b
    end
  end
end
