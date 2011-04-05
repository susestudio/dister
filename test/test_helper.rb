require File.expand_path('../../lib/dister',__FILE__)
require 'test/unit'
require 'mocha'
require 'shoulda'
require 'stringio'
require 'fakefs/safe'

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
    def initialize username, key, api_url, options={}
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
