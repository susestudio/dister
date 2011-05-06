# -*- encoding: utf-8 -*-
require File.expand_path("../lib/dister/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "dister"
  s.version     = Dister::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Flavio Castelli', 'Dominik Mayer']
  s.email       = ['flavio@castelli.name','dmayer@novell.com']
  s.homepage    = "https://github.com/flavio/dister"
  s.summary     = "Heroku like solution for SUSE Studio"
  s.description = "Turn your rails app into a SUSE Studio appliance in a few steps."

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "dister"

  s.add_dependency "curb"
  s.add_dependency "progressbar"
  s.add_dependency "studio_api", "~>3.1.1"
  s.add_dependency "thor", "~>0.14.0"

  s.add_development_dependency "bundler", "~>1.0.0"
  s.add_development_dependency "fakefs"
  s.add_development_dependency "mocha"
  s.add_development_dependency "test-unit", "1.2.3"
  s.add_development_dependency "shoulda"
  s.add_development_dependency "yard"
  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
