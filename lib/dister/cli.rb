module Dister
  class Cli < Thor
    include Thor::Actions

    def self.source_root
      File.expand_path('../../',__FILE__)
    end

    desc "create APPLIANCE_NAME", "create a new appliance named APPLIANCE_NAME"
    method_option :base_system,
      :type => :string, :default => 'openSUSE_latest', :required => false
    method_option :template,
      :type => :string, :default => 'JeOS', :required => false
    method_option :arch,
      :type => :string, :default => 'i686', :required => false
    def create(appliance_name)
      allowed_archs = %w(i686 x86_64)
      unless allowed_archs.include? options[:arch]
        STDERR.puts "#{options[:arch]} is not a valid arch"
        STDERR.puts "Valid archs are: #{allowed_archs.join(" ")}"
        exit 1
      end
    end

    desc "templates", "List all the templates available on SUSE Studio"
    def templates
      core = Core.new
      core.list_templates
    end
  end
end
