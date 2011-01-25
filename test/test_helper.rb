require 'rubygems'
require 'test/unit'
require 'mocha'
require 'shoulda'
require 'stringio'
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
