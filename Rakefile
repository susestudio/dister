require 'bundler'
require 'rake'
require 'rake/testtask'
Bundler::GemHelper.install_tasks

task :default => "test"

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
  puts "Yard not available. To generate documentation install it with: gem install yard"
end
