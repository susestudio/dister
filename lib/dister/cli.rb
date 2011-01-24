module Dister
  class Cli < Thor
    include Thor::Actions

    def self.source_root
      File.expand_path('../../',__FILE__)
    end

    desc "create APPLIANCE_NAME", "create a new appliance named APPLIANCE_NAME"
    method_option :base_system, :type => :string, :default => nil,
                                :required => false
    method_option :template, :type => :string, :default => 'JeOS',
                             :required => false
    method_option :arch, :type => :string, :default => 'i686',
                         :required => false
    def create(appliance_name)
      core = Core.new

      allowed_archs = %w(i686 x86_64)
      ensure_valid_option options[:arch], allowed_archs, "arch"

      base_systems = core.base_systems
      if options[:base_system].nil?
        # find latest version of openSUSE
        options[:base_system] = base_systems.find_all{|a| a =~ /\d+\.\d+/}.sort.last
      else
       ensure_valid_option options[:base_system], allowed_archs, "arch"
      end
    end

    desc "templates", "List all the templates available on SUSE Studio"
    def templates
      core = Core.new
      core.list_templates
    end

    desc "base_systems", "List all the base systems available on SUSE Studio"
    def base_systems
      core = Core.new
      core.base_systems.sort.each do |b|
        puts b
      end
    end

    private
    def ensure_valid_option actual_value, allowed_values, option_name
      unless allowed_values.include? actual_value
        STDERR.puts "#{actual_value} is not a valid value for #{option_name}"
        STDERR.puts "Valid values are: #{allowed_values.join(" ")}"
        exit 1
      end
    end
  end
end
