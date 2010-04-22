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
require 'gem_adapter'
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
POLISHER_CONFIG = load_polisher_config(Sinatra::Application)

##################################################################### Projects

# Redirect to /projects
get '/' do redirect '/projects.html'; end

get '/projects.html' do
  @projects  = Project.find :all
  @sources   = Source.find :all
  @processes = Event.processes
  @version_qualifiers = Event::VERSION_QUALIFIERS
  haml :"projects/index.html"
end

get '/projects' do
  @projects = Project.find :all
  haml :"projects/index", :layout => false
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

  haml :"result", :layout => false
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

  haml :"result", :layout => false
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

    # process project
    project.released_version(version, params)
    @result = {:success => true, :message => "successfully released project #{project.name}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to release project due to error #{e}", :errors => [e]}
  end

  haml :"result", :layout => false
end

##################################################################### Sources

get '/sources.html' do
  @sources  = Source.find :all
  @projects = Project.find :all
  haml :"sources/index.html"
end

get '/sources' do
  @sources = Source.find :all
  haml :"sources/index", :layout => false
end

post '/sources/create' do
  begin
    if params[:uri].nil? || params[:name].nil? || params[:source_type].nil?
      raise ArgumentError, "/sources/create received an invalid uri(#{params[:uri]}), name(#{params[:name]}) or source_type(#{params[:source_type]})"
    end

    @source = Source.new(:uri => params[:uri], :name => params['name'], :source_type => params[:source_type])
    @source.save!

    @result = {:success => true, :message => "successfully created source #{@source.uri}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to create source due to error #{e}", :errors => [e]}
    @source.errors.each_full { |e| @result[:errors] << e } unless @source.nil?
  end

  haml :"result", :layout => false
end

delete '/sources/destroy/:id' do
  begin
    if params[:id].nil?
      raise ArgumentError, "/sources/destroy/:id received an invalid id(#{params[:id]})"
    end

    source = Source.find(params[:id])
    if source.nil?
      raise ArgumentError, "/sources/destroy/#{params[:id]} could not find source"
    end

    source_uri = source.uri
    Source.delete params[:id]

    @result = {:success => true, :message => "successfully deleted source #{source_uri}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to delete source due to error #{e}", :errors => [e]}
  end

  haml :"result", :layout => false
end

post '/sources/released' do
  begin
    if params[:name].nil? || params[:version].nil?
      raise ArgumentError, "/sources/released received an invalid name(#{params[:name]}) or version(#{params[:version]})"
    end

    name    = params[:name]
    version = params[:version]
    # we also have gem_uri for gem sources

    source = Source.find(:first, :conditions => ["name = ?", name])
    if source.nil?
      raise ArgumentError, "/sources/released could not find source from name #{name}"
    end

    # find projects which include this source
    source.project_source_versions_for_version(version).each { |ps|
      # if we can't determine project version, use source version
      project_version = ps.project_version.nil? ? version : ps.project_version

      # invoke a release on the project
      ps.project.released_version(version, params)
    }

    @result = {:success => true, :message => "successfully released source #{name}", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to release source due to error #{e}", :errors => [e]}
  end

  haml :"result", :layout => false
end

##################################################################### ProjectSourceVersions

post '/project_source_versions/create' do
  begin
    if params[:project_id].nil? ||  params[:source_id].nil?
      raise ArgumentError, "/project_source_versions/create received an invalid project_id(#{params[:project_id]}) or source_id(#{params[:source_id]})"
    end

    project = Project.find(params[:project_id])
    source  = Source.find(params[:source_id])
    if project.nil? || source.nil?
      raise ArgumentError, "/project_source_versions/create could not find project or source from ids"
    end

    ps = ProjectSourceVersion.new :project => project, :source => source,
                            :project_version   => params[:project_version],
                            :source_version    => params[:source_version],
                            :source_uri_params => params[:source_uri_params],
                            :primary_source    => params[:primary_source]

    ps.save!
    @result = {:success => true, :message => "successfully created project source", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to create project source due to error #{e}", :errors => [e]}
  end

  haml :"result", :layout => false
end

delete '/project_source_versions/destroy/:id' do
  begin
    if params[:id].nil?
      raise ArgumentError, "/project_source_versions/destroy/:id received an invalid id(#{params[:id]})"
    end

    ps = ProjectSourceVersion.find(params[:id])
    if ps.nil?
      raise ArgumentError, "/project_source_versions/destroy/#{params[:id]} could not find project source"
    end

    ProjectSourceVersion.delete params[:id]
    @result = {:success => true, :message => "successfully deleted project source", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to delete project source due to error #{e}", :errors => [e]}
  end

  haml :"result", :layout => false
end

##################################################################### ProjectDependencies

post '/project_dependencies/create' do
  begin
    if params[:project_id].nil? ||  params[:depends_on_project_id].nil?
      raise ArgumentError, "/project_dependencies/create received an invalid project_id(#{params[:project_id]}) or depends_on_project_id(#{params[:depends_on_project_id]})"
    end

    project = Project.find(params[:project_id])
    depends_on = Project.find(params[:depends_on_project_id])
    if project.nil? || depends_on.nil?
      raise ArgumentError, "/project_dependencies/create could not find projects w/ specified ids(#{params[:project_id]}/#{params[:depends_on_project_id]})"
    end

    project_version    = (params[:project_version]    != '*' ? params[:project_version]   : nil)
    depends_on_version = (params[:depends_on_project_version] != '*' ? params[:depends_on_project_version]: nil)
    @pd = ProjectDependency.new  :project => project, :depends_on_project => depends_on,
                                 :project_version => project_version, :depends_on_project_version => depends_on_version,
                                 :depends_on_project_params => params[:depends_on_project_params]
    @pd.save!

    @result = {:success => true, :message => "successfully created project dependency", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to created project dependency due to error #{e}", :errors => [e]}
    @pd.errors.each_full { |e| @result[:errors] << e } unless @event.nil?
  end

  haml :"result", :layout => false
end

delete '/project_dependencies/destroy/:id' do
  begin
    if params[:id].nil?
      raise ArgumentError, "/project_dependencies/destroy/:id received an invalid id(#{params[:id]})"
    end

    pd = ProjectDependency.find(params[:id])
    if pd.nil?
      raise ArgumentError, "/project_dependencies/destroy/#{params[:id]} could not find project dependency"
    end

    ProjectDependency.delete params[:id]
    @result = {:success => true, :message => "successfully deleted project dependency", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to delete project dependency due to error #{e}", :errors => [e]}
  end

  haml :"result", :layout => false
end

##################################################################### Events

post '/events/create' do
  begin
    if params[:project_id].nil? ||  params[:process].nil?
      raise ArgumentError, "/events/create received an invalid project_id(#{params[:project_id]}) or process(#{params[:process]})"
    end

    project = Project.find(params[:project_id])
    if project.nil?
      raise ArgumentError, "/events/create could not find project w/ specified id(#{params[:project_id]})"
    end

    version           = (params[:version]       != '*' ? params[:version]       : nil)
    version_qualifier = (params[:version_qualifier] != ''  ? params[:version_qualifier] : nil)
    @event = Event.new  :project => project,
                        :version => version,
                        :version_qualifier => version_qualifier,
                        :process => params[:process],
                        :process_options => params[:process_options]
    @event.save!

    @result = {:success => true, :message => "successfully created event", :errors => []}

  rescue Exception => e
    @result = {:success => false, :message => "failed to created event due to error #{e}", :errors => [e]}
    @event.errors.each_full { |e| @result[:errors] << e } unless @event.nil?
  end

  haml :"result", :layout => false
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

  haml :"result", :layout => false
end
