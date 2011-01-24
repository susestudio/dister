require 'studio_api'

module Dister
  class Core
    def initialize
      # TODO obtain these details from Options class
      @connection = StudioApi::Connection.new('user',
                                              'pwd',
                                              'https://susestudio.com/api/v1/user')
      StudioApi::Util.configure_studio_connection @connection
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
    end
  end
end
