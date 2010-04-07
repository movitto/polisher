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
require 'sinatra/url_for'

# db modules
require 'db/connection'

##################################################################### Config

# dir which generated artifacts reside
ARTIFACTS_DIR = File.expand_path(Sinatra::Application.artifacts_dir)

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
  begin
    if params[:name].nil? || params[:gem_source_id].nil? || params[:name] == "" || params[:gem_source_id] == ""
      raise ArgumentError, "/gems/create received an invalid name(#{params[:name]}) or gem_source_id(#{params[:gem_source_id]})"
    end

    @gem = ManagedGem.new :name => params[:name], :gem_source_id => params[:gem_source_id]
    @gem.save!
    #@gem.subscribe

    @result = {:success => true, :message => "successfully created gem #{@gem.name}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to created gem due to error #{e}", :errors => [e]}
    @gem.errors.each_full { |e| @result[:errors] << e } unless @gem.nil?
  end

  haml :"result.xml", :layout => false
end

delete '/gems/destroy/:id' do 
  begin
    if params[:id].nil?
      raise ArgumentError, "/gems/destroy/:id received an invalid id(#{params[:id]})"
    end

    gem = ManagedGem.find(params[:id])
    if gem.nil?
      raise ArgumentError, "/gems/destroy/#{params[:id]} could not find gem"
    end

    gem_name = gem.name
    ManagedGem.delete params[:id]
    @result = {:success => true, :message => "successfully deleted gem #{gem_name}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to delete gem due to error #{e}", :errors => [e]}
  end

  haml :"result.xml", :layout => false
end

post '/gems/released' do
  begin
    if params[:name].nil? || params[:version].nil? || params[:gem_uri].nil?
      raise ArgumentError, "/gems/released received an invalid name(#{params[:name]}), version(#{params[:version]}) or gem_uri(#{params[:gem_uri]})"
    end

    name    = params[:name]
    version = params[:version]
    source_uri = ManagedGem.uri_to_source_uri(params[:gem_uri])

    source = GemSource.find(:first, :conditions => ["uri = ?", source_uri])
    if source.nil?
      raise ArgumentError, "/gems/released could not find gem source from uri(#{source_uri}) constructed from gem_uri(#{params[:gem_uri]})"
    end

    gem    = source.gems.all.find { |gem| gem.name == name }
    if gem.nil?
      raise ArgumentError, "/gems/released could not find gem with name(#{name}) with source(#{source.name})"
    end

    events = gem.events.all.find_all { |event| event.applies_to_version?(version) }
    events.each { |event| event.run(params) }
    @result = {:success => true, :message => "successfully released gem #{gem.name}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to release gem due to error #{e}", :errors => [e]}
  end

  haml :"result.xml", :layout => false
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
  begin
    if params[:name].nil? || params[:uri].nil? || params[:name] == "" || params[:uri] == ""
      raise ArgumentError, "/gem_sources/create received an invalid name(#{params[:name]}) or uri(#{params[:uri]})"
    end

    @gem_source = GemSource.new :name => params[:name], :uri => params[:uri]
    @gem_source.save!
    @result = {:success => true, :message => "successfully created gem_source #{@gem_source.name}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to created gem_source due to error #{e}", :errors => [e]}
    @gem_source.errors.each_full { |e| @result[:errors] << e } unless @gem_source.nil?
  end

  haml :"result.xml", :layout => false
end

delete '/gem_sources/destroy/:id' do 
  begin
    if params[:id].nil?
      raise ArgumentError, "/gems/destroy/:id received an invalid id(#{params[:id]})"
    end

    source = GemSource.find(params[:id])
    if source.nil?
      raise ArgumentError, "/gems/destroy/#{params[:id]} could not find source"
    end

    source_name = source.name
    GemSource.delete params[:id]
    @result = {:success => true, :message => "successfully deleted gem source #{source_name}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to delete gem source due to error #{e}", :errors => [e]}

  end

  haml :"result.xml", :layout => false
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
  begin
    if params[:name].nil? || params[:name] == ""
      raise ArgumentError, "/projects/create received an invalid name(#{params[:name]})"
    end

    @project = Project.new :name => params[:name]
    @project.save!

    @result = {:success => true, :message => "successfully created project #{@project.name}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to created project due to error #{e}", :errors => [e]}
    @project.errors.each_full { |e| @result[:errors] << e } unless @project.nil?
  end

  haml :"result.xml", :layout => false
end

delete '/projects/destroy/:id' do
  begin
    if params[:id].nil?
      raise ArgumentError, "/projects/destroy/:id received an invalid id(#{params[:id]})"
    end

    project = Project.find(params[:id])
    if project.nil?
      raise ArgumentError, "/projects/destroy/#{params[:id]} could not find project"
    end

    project_name = project.name
    Project.delete params[:id]
    @result = {:success => true, :message => "successfully deleted project #{project_name}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to delete project due to error #{e}", :errors => [e]}
  end

  haml :"result.xml", :layout => false
end

post '/projects/released' do
  begin
    if params[:name].nil? || params[:version].nil?
      raise ArgumentError, "/projects/released received an invalid name(#{params[:name]}) or version(#{params[:version]})"
    end

    name    = params[:name]
    version = params[:version]
    project = Project.find(:first, :conditions => ["name = ?", name])
    if project.nil?
      raise ArgumentError, "/projects/released could not find project from name #{name}"
    end

    events  = project.events.all.find_all { |event| event.applies_to_version?(version) }
    events.each { |event| event.run(params) }
    @result = {:success => true, :message => "successfully released project #{project.name}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to release project due to error #{e}", :errors => [e]}
  end

  haml :"result.xml", :layout => false
end

##################################################################### Project Sources

post '/project_sources/create' do
  begin
    if params[:uri].nil? || params[:project_id].nil?
      raise ArgumentError, "/project_sources/create received an invalid uri(#{params[:uri]}) or project_id(#{params[:project_id]})"
    end

    @source = ProjectSource.new(:uri => params[:uri], :project_id => params['project_id'])
    @source.save!

    @result = {:success => true, :message => "successfully created project source #{@source.uri}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to create project source due to error #{e}", :errors => [e]}
    @source.errors.each_full { |e| @result[:errors] << e } unless @source.nil?
  end

  haml :"result.xml", :layout => false
end

delete '/project_sources/destroy/:id' do
  begin
    if params[:id].nil?
      raise ArgumentError, "/project_sources/destroy/:id received an invalid id(#{params[:id]})"
    end

    source = ProjectSource.find(params[:id])
    if source.nil?
      raise ArgumentError, "/project_sources/destroy/#{params[:id]} could not find source"
    end

    source_uri = source.uri
    ProjectSource.delete params[:id]

    @result = {:success => true, :message => "successfully deleted project source #{source_uri}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to delete project source due to error #{e}", :errors => [e]}
  end

  haml :"result.xml", :layout => false
end

##################################################################### Events

post '/events/create' do
  begin
    if (params[:managed_gem_id].nil? && params[:project_id].nil?) ||  params[:process].nil?
      raise ArgumentError, "/events/create received an invalid managed_gem_id(#{params[:managed_gem_id]}), project_id(#{params[:project_id]}), or process(#{params[:process]})"
    end

    target_key = nil
    target_obj = nil
    if params.has_key?('managed_gem_id')
      target_key = :managed_gem
      target_obj = ManagedGem.find(params[:managed_gem_id])
    elsif params.has_key?('project_id')
      target_key = :project
      target_obj = Project.find(params[:project_id])
    end

    if target_key.nil? || target_obj.nil?
      raise ArgumentError, "/events/create could not find #{target_key} w/ specified params"
    end

    version           = (params[:gem_version]       != '*' ? params[:gem_version]       : nil)
    version_qualifier = (params[:version_qualifier] != ''  ? params[:version_qualifier] : nil)
    @event = Event.new  target_key => target_obj,
                        :process => params[:process],
                        :gem_version => version,
                        :version_qualifier => version_qualifier,
                        :process_options => params[:process_options]
    @event.save!

    @result = {:success => true, :message => "successfully created event", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to created event due to error #{e}", :errors => [e]}
    @event.errors.each_full { |e| @result[:errors] << e } unless @event.nil?
  end

  haml :"result.xml", :layout => false
end

delete '/events/destroy/:id' do 
  begin
    if params[:id].nil?
      raise ArgumentError, "/events/destroy/:id received an invalid id(#{params[:id]})"
    end

    event = Event.find(params[:id])
    if event.nil?
      raise ArgumentError, "/events/destroy/#{params[:id]} could not find event"
    end

    Event.delete params[:id]
    @result = {:success => true, :message => "successfully deleted event", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to delete event due to error #{e}", :errors => [e]}
  end

  haml :"result.xml", :layout => false
end
