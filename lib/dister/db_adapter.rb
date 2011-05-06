require 'erb'

module Dister
  class DbAdapter

    def initialize db_config_file, dump=nil
      config = YAML.load_file(db_config_file)
      if !config.has_key?("production")
        STDERR.puts "There's no configuration for the production environment"
      end

      @adapter  = config["production"]["adapter"]
      @user     = config["production"]["username"]
      @password = config["production"]["password"]
      @dbname   = config["production"]["adapter"]
      @dump     = dump

      filename = File.expand_path("../../adapters/#{@adapter}.yml", __FILE__)
      raise "There's no adapter for #{@adapter}" if !File.exists?(filename)

      @adapter_config = YAML.load_file(filename)
    end

    def has_dump?
      return false if @dump.nil?
      return File.exists? @dump
    end

    def cmdline_tool
      @adapter_config["cmdline_tool"]
    end

    def packages
      @adapter_config["packages"]
    end

    def daemon_name
      @adapter_config["daemon_name"]
    end

    def create_user_cmd
      compile_cmd @adapter_config["create_user_cmd"]
    end

    def restore_dump_cmd
      compile_cmd @adapter_config["restore_dump_cmd"]
    end

    private
    def compile_cmd cmd
      return "" if cmd.nil?

      erb = ERB.new cmd
      erb.result(binding)
    end
  end
end
