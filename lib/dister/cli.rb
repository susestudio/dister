module Dister
  class Cli < Thor
    include Thor::Actions

    def self.source_root
      File.expand_path('../../',__FILE__)
    end

    VALID_TEMPLATES = %w(JeOS Server X Gnome KDE)

    desc "init", "Creates all files needed by Dister. Make sure to run it from Rails root"
    def init
      #TODO look for authentication
      #create .dister directory containing appliance-specific setting
    end

    desc "create APPLIANCE_NAME", "create a new appliance named APPLIANCE_NAME"
    method_option :basesystem, :type => :string, :default => nil,
                                :required => false
    method_option :template, :type => :string, :default => 'JeOS',
                             :required => false
    method_option :arch, :type => :string, :default => 'i686',
                         :required => false
    def create(appliance_name)
      core = Core.new

      allowed_archs = %w(i686 x86_64)
      ensure_valid_option options[:arch], allowed_archs, "arch"

      basesystems = core.basesystems
      basesystem = options[:basesystem] || basesystems.find_all{|a| a =~ /\d+\.\d+/}.sort.last
      ensure_valid_option basesystem, basesystems, "base system"

      ensure_valid_option options[:template], VALID_TEMPLATES, "template"

      core.create_appliance appliance_name, options[:template],
                            basesystem, options[:arch] 
    end
    
    desc "build", "Builds the appliance"
    def build
      #TODO: make sure the appliance has been created
      #TODO: read appliance ID from the settings file
      appliance_id = 318430
      if (Core.new.build appliance_id)
        puts "Appliance successfully built."
      else
        puts "Something went wrong."
    end

    desc "templates", "List all the templates available on SUSE Studio"
    def templates
      VALID_TEMPLATES.sort.each do |t|
        puts t
      end
    end

    desc "basesystems", "List all the base systems available on SUSE Studio"
    def basesystems
      core = Core.new
      core.basesystems.sort.each do |b|
        puts b
      end
    end

    private
    def ensure_valid_option actual_value, allowed_values, option_name
      if allowed_values.find{|v| v.downcase == actual_value.downcase}.nil?
        STDERR.puts "#{actual_value} is not a valid value for #{option_name}"
        STDERR.puts "Valid values are: #{allowed_values.join(" ")}"
        exit 1
      end
    end
  end
end
