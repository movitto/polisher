require 'rubygems'
require 'sinatra'

dir = File.dirname(__FILE__) 

set :artifacts_dir     => dir + '/artifacts'
set :polisher_config   => dir + '/config/polisher.yml'
set :db_config         => dir + '/config/database.yml'
set :db_data_dir       => dir + '/db/data'
set :log_dir          => dir + '/log/'
set :environment       => :development
set :run               => false
set :logging, true

#log = File.new(dir + "/log/sinatra.log", "a+")
#$stdout.reopen(log)
#$stderr.reopen(log)

set :raise_errors => true
use Rack::ShowExceptions

$: << "lib/"

require 'polisher.rb'
run Sinatra::Application
