ENV["RAILS_ENV"] = "test"
$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'lib')
$LOAD_PATH << File.dirname(__FILE__)

require 'minitest/autorun'
require 'purdytest'
require "active_support"
require "action_controller"
require "rails/railtie"
#require "rails/test_helper"
require "logger"
require 'sqlite3'

require 'letmein'

#$stdout_orig = $stdout
#$stdout = StringIO.new
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
#ActiveRecord::Base.logger = Logger.new($stdout)
ActiveRecord::Base.logger = Logger.new('/dev/null')

ActionController::Base.view_paths = File.join(File.dirname(__FILE__), 'views')

LetMeIn::Routes = ActionDispatch::Routing::RouteSet.new
LetMeIn::Routes.draw do
  match ':controller(/:action(/:id))'
end

ActionController::Base.send :include, LetMeIn::Routes.url_helpers

puts "HERE !!!"
