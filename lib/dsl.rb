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

# DSL representations of model classes (so as to not require db connection on client side)

# DSL Managed Gem
class ManagedGem
  # Managed gem attributes
  attr_accessor :id, :name, :source, :gem_source_id

  def initialize(args = {})
    @id      = args[:id]     if args.has_key? :id
    @name    = args[:name]   if args.has_key? :name
    @source  = args[:source] if args.has_key? :source
    @gem_source_id  = args[:gem_source_id] if args.has_key? :gem_source_id
  end

   # Create ManagedGem from xml
   def self.from_xml(xml_str)
     gem = Polisher::ManagedGem.new

     xml = LibXML::XML::Document.string(xml_str).root
     gem.id   = xml.children.find { |c| c.name == "id" }.content.to_i
     gem.name = xml.children.find { |c| c.name == "name" }.content.strip
     gem.gem_source_id = xml.children.find { |c| c.name == "gem_source_id" }.content.to_i
     gem.source = sources.find { |s| s.id == gem.gem_source_id }

     return gem
   end

   # Create new Event w/ the specified version qualifier, version, process, and process optiosn
   def on_version(version_qualifier, version, process, process_options = [])
     RestClient.post("#{$polisher_uri}/events/create", 
                    :managed_gem_id => id, :process => process, :gem_version => version,
                    :version_qualifier => version_qualifier, :process_options => process_options) { |response| }
   end

   # Delete managed gem
   def delete
     RestClient.delete("#{$polisher_uri}/gems/destroy/#{id}"){ |response| }
   end

   # Test fire gem released event for specified version
   def released(version)
     RestClient.post("#{$polisher_uri}/gems/released",
                    :name    => name, :version => version, 
                    :gem_uri => source.uri + "/gems/#{name}-#{version}.gem" ) { |response| }
   end
end

# DSL Gem Source
class GemSource
  # Gem source attributes
  attr_accessor :id, :name, :uri

  def initialize(args = {})
    @sources = []
    @id      = args[:id]     if args.has_key? :id
    @name    = args[:name]   if args.has_key? :name
    @uri     = args[:uri]    if args.has_key? :uri
  end

   # Create GemSource from xml and return
   def self.from_xml(xml_str)
     source = Polisher::GemSource.new

     xml = LibXML::XML::Document.string(xml_str).root
     source.id   = xml.children.find { |c| c.name == "id" }.content.to_i
     source.name = xml.children.find { |c| c.name == "name" }.content.strip
     source.uri  = xml.children.find { |c| c.name == "uri" }.content.strip

     return source
   end
end

# DSL Project
class Project
  # Project attributes
  attr_accessor :id, :name, :sources

  def initialize(args = {})
    @sources = []
    @id      = args[:id]     if args.has_key? :id
    @name    = args[:name]   if args.has_key? :name
  end

  # Create Project from xml and return
  def self.from_xml(xml_str)
    project = Polisher::Project.new

    xml = LibXML::XML::Document.string(xml_str).root
    project.id   = xml.children.find { |c| c.name == "id" }.content.to_i
    project.name = xml.children.find { |c| c.name == "name" }.content.strip
    xml.children.find     { |c| c.name == "sources" }.children.each  { |c|
       uri = c.children.find { |c| c.name == "uri"}
       project.sources  << uri.content.strip unless uri.nil?
    }

    return project
  end

  # Create new Event w/ the specified version qualifier, version, process, and process optiosn
  def on_version(version_qualifier, version, process, process_options = [])
    RestClient.post("#{$polisher_uri}/events/create", 
                   :project_id => id, :process => process, :gem_version => version,
                   :version_qualifier => version_qualifier, :process_options => process_options) { |response| }
  end

  # Delete project
  def delete
    RestClient.delete("#{$polisher_uri}/projects/destroy/#{id}") { |response| }
  end

  # Add new Project source w/ specified uri
  def add_source(uri)
    sources << uri
    RestClient.post("#{$polisher_uri}/project_sources/create", :project_id => id, :uri => uri) { |response| }
  end

  # Test fire project released event for specified version
  def released(version)
     RestClient.post("#{$polisher_uri}/projects/released",
                    :name    => name, :version => version ) { |response| }
  end
end

end # module Polisher

# Set polisher uri for all connections
def polisher(uri)
  # XXX do this better
  $polisher_uri = uri
end

# Retrieve list of all gems, invoking yield w/ each gem, before running the list
def gems
  gems = []
  RestClient.get("#{$polisher_uri}/gems.xml") { |response| 
    xml = LibXML::XML::Document.string(response.body).root
    xml.children.find_all { |c| c.name == "gem" }.each { |s|
      gems << Polisher::ManagedGem.from_xml(s.to_s)
    }
  }
  gems.each { |gem| yield gem if block_given? }
  return gems
end

# Find or create new gem w/ specified args, invoke yield w/ it, and return it
def gem(args = {})
  gems.each { |gem|
    gem = nil if (args.has_key?(:name)   && args[:name]   != gem.name) ||
                 (args.has_key?(:id)     && args[:id]     != gem.id)   ||
                 (args.has_key?(:source) && args[:source] != gem.source.name)
    unless gem.nil?
      yield gem if block_given?
      return gem
    end
  }
  args[:gem_source_id] = sources.find { |s| s.name == args[:source] }.id
  RestClient.post("#{$polisher_uri}/gems/create", args) { |response| }
  gem = gem(args)
  yield gem if block_given?
  return gem
end

# Retrieve list of all sources, invoking yield w/ each source, before running the list
def sources
  sources = []
  RestClient.get("#{$polisher_uri}/gem_sources.xml") { |response| 
    xml = LibXML::XML::Document.string(response.body).root
    xml.children.find_all { |c| c.name == "source" }.each { |s|
      sources << Polisher::GemSource.from_xml(s.to_s)
    }
  }
  sources.each { |source| yield source if block_given? }
  return sources
end

# Find or create new gem source w/ specified args, invoke yield w/ it, and return it
def source(args = {})
  sources.each { |source|
    source = nil if (args.has_key?(:name) && args[:name] != source.name) ||
                    (args.has_key?(:uri)  && args[:uri]  != source.uri) ||
                    (args.has_key?(:id)   && args[:id]   != source.id)
    unless source.nil?
      yield source if block_given?
      return source
    end
  }
  RestClient.post("#{$polisher_uri}/gem_sources/create", args) { |response| }
  source = source(args)
  yield source if block_given?
  return source
end

# Retrieve list of all projects, invoking yield w/ each source, before running the list
def projects
  projects = []
  RestClient.get("#{$polisher_uri}/projects.xml") { |response| 
    xml = LibXML::XML::Document.string(response.body).root
    xml.children.find_all { |c| c.name == "project" }.each { |s|
      projects << Polisher::Project.from_xml(s.to_s)
    }
  }
  projects.each { |project| yield project if block_given? }
  return projects
end

# Find or create new project w/ specified args
def project(args = {})
  projects.each { |project|
    project = nil if (args.has_key?(:name) && args[:name] != project.name) ||
                     (args.has_key?(:id)   && args[:id]   != project.id)
    unless project.nil?
      yield project if block_given?
      return project 
    end
  }
  RestClient.post("#{$polisher_uri}/projects/create", args) { |response| }
  project = project(args)
  yield project if block_given?
  return project
end

