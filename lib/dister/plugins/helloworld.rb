require 'rubygems'
require 'thor'

#TODO: way of describing the plugin
module Dister
  class HelloWorld < Thor

    desc "hello", "Prints 'hello world'"
    def hello
      puts "hello world"
    end
  end
end

Dister::HelloWorld.start(ARGV)
