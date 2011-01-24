require 'thor'

module Dister
  class Cli < Thor
    include Thor::Actions

    def self.source_root; File.expand_path('../../',__FILE__); end

    desc "create APPLIANCE_NAME", "create a new appliance named APPLIANCE_NAME"
    method_option :base_system, :type => :string, :default => 'openSUSE_latest'
    method_option :template, :type => :string, :default => 'JeOS'
    method_option :arc, :type => :string, :default => 'x86'
    def create(appliance_name)
      puts appliance_name
      puts options.inspect
    end
  end
end
