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
  @gem_sources   = GemSource.find :all
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
  # FIXME throw exception if params[:gem_source_id].nil?
  @gem = ManagedGem.new :name => params[:name], :gem_source_id => params[:gem_source_id]
  @gem.save!
  @gem.subscribe
  redirect '/gems'
end

delete '/gems/destroy/:id' do 
  ManagedGem.delete params[:id]
  redirect '/gems'
end

post '/gems/released' do
  name    = params[:name]
  version = params[:version]
  source_uri = ManagedGem.uri_to_source_uri(params[:gem_uri]) 

  source = GemSource.find(:first, :conditions => ["uri = ?", source_uri])
  gem    = source.gems.all.find { |gem| gem.name == name }
  events = gem.events.all.find_all { |event| event.applies_to_version?(version) }
  events.each { |event| event.run }

  redirect '/gems'
end

##################################################################### GemSources

get '/gem_sources' do
  @gem_sources = GemSource.find :all
  haml :"gem_sources/index"
end

get '/gem_sources.xml' do
  @gem_sources = GemSource.find :all
  haml :"gem_sources/index.xml", :layout => false
end

post '/gem_sources/create' do
  @gem_source = GemSource.new :name => params[:name], :uri => params[:uri]
  @gem_source.save!
  redirect '/gem_sources'
end

delete '/gem_sources/destroy/:id' do 
  GemSource.delete params[:id]
  redirect '/gem_sources'
end

##################################################################### Projects

get '/projects' do
  @projects = Project.find :all
  haml :"projects/index"
end

get '/projects.xml' do
  @projects = Project.find :all
  haml :"projects/index.xml", :layout => false
end

post '/projects/create' do
  project = Project.new :name => params[:name]
  project.save!
  redirect '/projects'
end

delete '/projects/destroy/:id' do
  Project.delete params[:id]
  redirect '/projects'
end

post '/projects/released' do
  name    = params[:name]
  version = params[:version]
  project = Project.find(:first, :conditions => ["name = ?", name])
  events  = project.events.all.find_all { |event| event.applies_to_version?(version) }
  events.each { |event| event.run(params) }

  redirect '/gems'
end

##################################################################### Project Sources

post '/project_sources/create' do
  ProjectSource.create!(:uri => params[:uri], :project_id => params['project_id'])
  redirect '/projects'
end

delete '/project_sources/destroy/:id' do
  ProjectSource.delete params[:id]
  redirect '/projects'
end

##################################################################### Events

post '/events/create' do
  target_key = nil
  target_obj = nil
  if params.has_key?('managed_gem_id')
    target_key = :managed_gem
    target_obj = ManagedGem.find(params[:managed_gem_id])
  elsif params.has_key?('project_id')
    target_key = :project
    target_obj = Project.find(params[:project_id])
  end

  version = (params[:gem_version] != '*' ? params[:gem_version] : '')
  @event = Event.new  target_key => target_obj,
                      :process => params[:process],
                      :gem_version => version,
                      :version_qualifier => params[:version_qualifier],
                      :process_options => params[:process_options]
  @event.save!
  redirect '/gems'     if target_key == :managed_gem
  redirect '/projects' if target_key == :project
end

delete '/events/destroy/:id' do 
  Event.delete params[:id]
  redirect '/gems'
end
