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

    desc "init", "Creates all files needed by Dister. Make sure to run it from Rails root"
    def init
      #TODO look for authentication
      #create .dister directory containing appliance-specific setting
    end

    desc "create APPLIANCE_NAME", "create a new appliance named APPLIANCE_NAME"
    method_option :basesystem,
      :type => :string, :default => nil, :required => false
    method_option :template,
      :type => :string, :default => 'JeOS', :required => false
    method_option :arch,
      :type => :string, :default => 'i686', :required => false
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
    end

    desc "format OPERATION FORMAT", "Enables building of FORMAT"
    def format(operation,format)
      valid_operations = %w(add rm)
      ensure_valid_option operation, valid_operations, "format"
      case format
      when "add"
        ensure_valid_option format, VALID_FOMATS, "format"
        #TODO: local options store format
      when "rm"
        #TODO: local options: remove format
      end
    end

    desc "formats", "List all the available formats"
    method_option :all,
      :type => :boolean, :default => false, :required => false
    def formats
      if options[:all]
        VALID_FOMATS.each do |f|
          puts "  #{f}"
        end
      else
        #TODO: local options: show enabled formats
      end
    end

    desc "templates", "List all the templates available on SUSE Studio"
    def templates
      puts VALID_TEMPLATES.sort
    end

    desc "basesystems", "List all the base systems available on SUSE Studio"
    def basesystems
      puts Core.new.basesystems.sort
    end

    private

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
