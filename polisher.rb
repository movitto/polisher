# ruby gem polisher REST interface
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

# ruby gems
require 'rubygems'
require 'haml'
require 'sinatra'
require 'fileutils'

# lib/ modules
require 'common'
require 'event_handlers'
require 'sinatra/url_for'

# db modules
require 'db/connection'

##################################################################### Config

# dir which generated artifacts reside
ARTIFACTS_DIR = Sinatra::Application.artifacts_dir

create_missing_polisher_dirs(:artifacts_dir => ARTIFACTS_DIR, :db_data_dir => Sinatra::Application.db_data_dir, :log_dir => Sinatra::Application.log_dir)

# startup logger
LOGGER = Logger.new(Sinatra::Application.log_dir + '/polisher.log')

# connect to db
module Polisher::DB
   connect load_config(Sinatra::Application.db_config, Sinatra::Application.environment), LOGGER
end

# get polisher config
POLISHER_CONFIG = YAML::load(File.open(Sinatra::Application.polisher_config))[Sinatra::Application.environment.to_s]

##################################################################### Gems
 
# Redirect to /gems
get '/' do redirect '/gems'; end

get '/gems' do
  @sources   = Source.find :all
  @gems      = ManagedGem.find :all
  @processes = Event.processes 
  @version_qualifiers = Event::VERSION_QUALIFIERS

  haml :"gems/index"
end

get '/gems.xml' do
  @gems      = ManagedGem.find :all
  haml :"gems/index.xml", :layout => false
end

post '/gems/create' do
  @gem = ManagedGem.new :name => params[:name], :source_id => params[:source_id]
  @gem.save!
  @gem.subscribe
  redirect '/gems'
end

delete '/gems/destroy/:id' do 
  ManagedGem.delete params[:id]
  redirect '/gems'
end

post '/gems/updated' do
  name    = params[:name]
  version = params[:version]
  source_uri = ManagedGem.uri_to_source_uri(params[:gem_uri]) 

  source = Source.find(:first, :conditions => ["uri = ?", source_uri])
  gem    = source.gems.all.find { |gem| gem.name == name }
  events = gem.events.all.find_all { |event| event.applies_to_version?(version) }
  events.each { |event| event.run }

  redirect '/gems'
end

##################################################################### Sources

get '/sources' do
  @sources = Source.find :all
  haml :"sources/index"
end

get '/sources.xml' do
  @sources = Source.find :all
  haml :"sources/index.xml", :layout => false
end

post '/sources/create' do
  @source = Source.new :name => params[:name], :uri => params[:uri]
  @source.save!
  redirect '/sources'
end

delete '/sources/destroy/:id' do 
  Source.delete params[:id]
  redirect '/sources'
end

##################################################################### Events

post '/events/create' do
  version = (params[:gem_version] != '*' ? params[:gem_version] : '')
  @event = Event.new  :managed_gem_id  => ManagedGem.find(params[:managed_gem_id]),
                      :process => params[:process],
                      :gem_version => version,
                      :version_qualifier => params[:version_qualifier],
                      :process_options => params[:process_options]
  @event.save!
  redirect '/gems'
end

delete '/events/destroy/:id' do 
  Event.delete params[:id]
  redirect '/gems'
end
