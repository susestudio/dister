require 'rubygems'
require 'thor'
require 'studio_api'
require 'yaml'
require 'progressbar'
require 'curb'

require File.expand_path('../dister/cli', __FILE__)
require File.expand_path('../dister/core', __FILE__)
require File.expand_path('../dister/options', __FILE__)
require File.expand_path('../dister/utils', __FILE__)
require File.expand_path('../dister/downloader', __FILE__)
require File.expand_path('../dister/db_adapter', __FILE__)
require File.expand_path('../studio_api/build', __FILE__)

module Dister

  autoload :Version, File.expand_path('../dister/version', __FILE__)

end
