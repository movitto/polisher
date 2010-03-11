# polisher spec system helper
#
# Copyright (C) 2010 Red Hat, Inc.
# Written by Mohammed Morsi <mmorsi@redhat.com>
#
# This program is free software, you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation, either version 3
# of the License, or (at your option) any later version.
# 
# You should have received a copy of the the GNU Affero
# General Public License, along with Polisher. If not, see 
# <http://www.gnu.org/licenses/>

require 'rubygems'
require 'sinatra'
require 'rack/test'
require 'spec'
require 'spec/autorun'
require 'spec/interop/test'

dir = File.expand_path(File.dirname(__FILE__) + '/..' )

# set polisher conf
set :artifacts_dir   => dir + '/spec/artifacts'
set :polisher_config => dir + '/config/polisher.yml'
set :db_config       => dir + '/config/database.yml'
set :log_dir         => dir + '/log'
set :db_data_dir     => dir + '/db/data'

# set test environment
set :environment, :test
set :run, false
set :raise_errors, true
set :logging, true
set :views, dir + '/views'

require File.join(File.dirname(__FILE__), '..', 'polisher')

Test::Unit::TestCase.send :include, Rack::Test::Methods 

def app
  Sinatra::Application
end
