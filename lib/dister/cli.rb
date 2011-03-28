module Dister

  class Cli < Thor

    include Thor::Actions

    # Returns Dister's root directory.
    # NOTE: Some of Thor's actions require this method to be defined.
    def self.source_root
      File.expand_path('../../',__FILE__)
    end

    desc "first_plugin", "Prints 'hello world'"
    def first_plugin option=""
      system("ruby lib/dister/plugins/helloworld.rb #{option}")
    end

    private

    # Convenience method to reduce duplicity and improve readability.
    # Sets @core
    def access_core
      @core ||= Core.new
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
