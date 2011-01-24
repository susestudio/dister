require 'rubygems'
require 'thor'
require 'studio_api'
require File.expand_path('../dister/cli', __FILE__)
require File.expand_path('../dister/core', __FILE__)

module Dister
  autoload :Version, File.expand_path('../dister/version', __FILE__)
end
