# Polisher dsl
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

require 'libxml'
require 'rest_client'

module Polisher

# helper method to handle (print) xml status response
def handle_response(operation, response, exception_on_fail = false)
  rr = LibXML::XML::Document.string(response.body).root
  success = rr.children.find { |c| c.name == "success" }.content.strip == "true"
  msg  = rr.children.find { |c| c.name == "message" }.content.strip
  puts "#{operation} returned w/ success = #{success} and the message: #{msg}"
  raise RuntimeError, "#{operation} returned w/ failed status: #{msg}" if exception_on_fail && !success
end
module_function :handle_response

# DSL representations of model classes (so as to not require db connection on client side)

# DSL project
class Project
  # Project attributes
  attr_accessor :id, :name

  # Means to store project version to be used when setting up projects_sources
  attr_accessor :project_version

  def initialize(args = {})
    args = {:id => nil, :name => nil}.merge(args)
    @id = args[:id] ; @name = args[:name]
  end

  # Add a method to project for each source type, eg add_archive, add_path, add_repo, etc.
  # Simply dispatch to source handler dsl method
  ::Source::SOURCE_TYPES.each { |st|
    define_method "add_#{st}".intern do |args|
      src = source(args)
      yield src if block_given?
    end
  }

  # Create Project from xml and return
  def self.from_xml(xml_str)
    project = Polisher::Project.new

    xml = LibXML::XML::Document.string(xml_str).root
    project.id   = xml.children.find { |c| c.name == "id" }.content.to_i
    project.name = xml.children.find { |c| c.name == "name" }.content.strip
    # TODO associated versions, sources, events
    #xml.children.find     { |c| c.name == "version" }.children.each  { |c|
       #uri = c.children.find { |c| c.name == "uri"}
       #project.sources  << uri.content.strip unless uri.nil?
    #}

    return project
  end

  # Retrieve and return all projects
  def self.all
    projects = []
    RestClient.get("#{$polisher_uri}/projects") { |response|
      xml = LibXML::XML::Document.string(response.body).root
      xml.children.find_all { |c| c.name == "project" }.each { |s|
        projects << Polisher::Project.from_xml(s.to_s)
      }
    }
    return projects
  end

  # Create project
  def create
    RestClient.post("#{$polisher_uri}/projects/create", :name => name) { |response| Polisher.handle_response('create project', response, true) }
  end

  # Delete project
  def delete
    RestClient.delete("#{$polisher_uri}/projects/destroy/#{id}") { |response| Polisher.handle_response('delete project', response, true) }
  end

  # Create new Event w/ the specified version qualifier, version, process, and process optiosn
  def on_version(*args)
    args.unshift nil if args.size == 3
    version_qualifier = args[0]
    version           = args[1]
    process           = args[2]
    process_options   = args[3]

    process.gsub!(/\s/, '_')

    RestClient.post("#{$polisher_uri}/events/create",
                   :project_id => id, :process => process, :version => version,
                   :version_qualifier => version_qualifier, :process_options => process_options) { |response| Polisher.handle_response('create event', response) }
  end

  # Associate specified project version w/ corresponding source version if specified,
  # else if not just return self
  def version(version, args = {})
    unless args.has_key?(:corresponds_to)
      @project_version = version
      return self
    end
    source = args[:corresponds_to]
    args = {:project_id => id,     :project_version => version,
            :source_id  => source.id, :source_version  => source.source_version, :source_uri_params => source.uri_args}
    RestClient.post("#{$polisher_uri}/projects_sources/create", args) { |response| Polisher.handle_response('created project source', response) }
  end

  # Test fire project released event for specified version
  def released(version, params = {})
     rparams = { :name => name, :version => version}.merge(params)
     RestClient.post("#{$polisher_uri}/projects/released", rparams ) { |response| Polisher.handle_response('released project', response) }
  end
end

# DSL Source
class Source
  # Source attributes
  attr_accessor :id, :name, :uri, :source_type

  # Means to store source version and optional uri params to be used when setting up project sources
  attr_accessor :source_version, :uri_args

  def initialize(args = {})
    args = { :id => nil, :name => nil, :uri => nil, :source_type => nil}.merge(args)
    @id = args[:id] ; @name = args[:name] ; @uri = args[:uri] ; @source_type = args[:source_type]
    @uri_args = ''
  end

  # Create Source from xml and return
  def self.from_xml(xml_str)
    source = Polisher::Source.new

    xml = LibXML::XML::Document.string(xml_str).root
    source.id   = xml.children.find { |c| c.name == "id" }.content.to_i
    source.name = xml.children.find { |c| c.name == "name" }.content.strip
    source.uri  = xml.children.find { |c| c.name == "uri" }.content.strip
    source.source_type = xml.children.find { |c| c.name == "source_type" }.content.strip
    # TODO associated versions, projects, events

    return source
  end

  # Retrieve and return all sources
  def self.all
    sources = []
    RestClient.get("#{$polisher_uri}/sources") { |response|
      xml = LibXML::XML::Document.string(response.body).root
      xml.children.find_all { |c| c.name == "source" }.each { |s|
        sources << Polisher::Source.from_xml(s.to_s)
      }
    }
    return sources
  end

  # Create source
  def create
    RestClient.post("#{$polisher_uri}/sources/create", :name => name, :uri => uri, :source_type => source_type) { |response| Polisher.handle_response('create project', response, true) }
  end

  # Associate specified project source w/ corresponding source version if specified,
  # else if not just return self
  def version(version, args = {})
    project = args.delete(:corresponds_to)

    @uri_args = args.keys.collect { |k| k.to_s + "=" + args[k].to_s }.join(";")

    if project.nil?
      @source_version = version
      return self
    end

    args = {:project_id => project.id, :project_version => project.project_version,
            :source_id  => id,  :source_version  => version, :source_uri_params => @uri_args}
    RestClient.post("#{$polisher_uri}/projects_sources/create", args) { |response| Polisher.handle_response('created project source', response) }
  end

  # Set source as primary in project/source associations
  def is_the_primary_source
    @uri_args[:primary_source] = true
  end
end

end # module Polisher

# Set polisher uri for all connections
def polisher(uri)
  # XXX do this better
  $polisher_uri = uri
end

# Retrieve list of all projects, invoking yield w/ each, before returning the list
def projects
  projects = Polisher::Project.all
  projects.each { |project| yield project if block_given? }
  return projects
end

# Find or create new project w/ specified args
def project(args = {})
  projects { |project|
    project = nil if (args.has_key?(:name) && args[:name] != project.name) ||
                     (args.has_key?(:id)   && args[:id]   != project.id)
    unless project.nil?
      yield project if block_given?
      return project
    end
  }
  proj = Polisher::Project.new args
  proj.create
  proj = project(args)
  yield proj if block_given?
  return proj
end

# Retrieve list of all sources, invoking yield w/ each, before returning the list
def sources
  sources = Polisher::Source.all
  sources.each { |source| yield source if block_given? }
  return sources
end

# Find or create new source w/ specified args
def source(args = {})
  sources { |src|
    src = nil if (args.has_key?(:name) && args[:name] != src.name) ||
                 (args.has_key?(:id)   && args[:id]   != src.id)   ||
                 (args.has_key?(:source_type) && args[:source_type] != src.source_type) ||
                 (args.has_key?(:uri)  && args[:uri]  != src.uri)
    unless src.nil?
      yield src if block_given?
      return src
    end
  }
  src = Polisher::Source.new args
  src.create
  src = source(args)
  yield src if block_given?
  return src
end
