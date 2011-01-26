require 'rubygems'
require 'fakefs/safe'
require 'mocha'
require 'shoulda'
require 'stringio'
require 'test/unit'
require 'yaml'
require File.expand_path('../../lib/dister',__FILE__)

class Object
  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end
    result
  end
end

module StudioApi
  class Connection
    def initialize username, key, api_url
      true
    end

    def api_version
    end
  end

  class Util
    def self.configure_studio_connection connection
    end
  end
end
