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

require 'curl' # requires 'curb' package

class Source < ActiveRecord::Base
  # TODO on delete, destroy these
  has_many :projects_sources
  has_many :projects, :through => :projects_sources

  validates_presence_of   :name
  validates_uniqueness_of :name
  validates_presence_of   :source_type
  validates_presence_of   :uri
  validates_uniqueness_of :uri

  # TODO split 'file' source type into 'archive', 'patch', etc?

  SOURCE_TYPES = ['file', 'gem', 'git_repo']

  validates_inclusion_of :source_type, :in => SOURCE_TYPES

  # Extract filename of this source from path
  def filename
    URI::parse(uri).path.split('/').last
  end

  # Return all projects_sources associated w/ particular version of the source
  def projects_sources_for_version(version)
    psa = projects_sources
    psa.find_all { |ps| ps.source_version == version || ps.source_version.nil? }
  end

  # Return all projects associated w/ particular version of the source
  def projects_for_version(version)
    projects_sources_for_version(version).collect { |ps| ps.project }
  end

  # Return all versions which we have configured this project for
  def versions
    (projects_sources.collect { |ps| ps.source_version }).uniq - [nil]
  end

  # Swap any occurence of the specified hash
  # keys w/ their cooresponding values in the local source uri
  def format_uri!(variables)
    params = {}
    if variables.class == String
      variables.split(';').each { |p| u = p.split('='); params[u[0]] = u[1] }
    elsif variables.class == Hash
      params = variables
    else
      return
    end

    turi = uri
    params.each { |k,v| turi.gsub!("%{#{k}}", v.to_s) }
    uri = turi
  end

  # Download source, args may contain any of the following
  # * :path path to download source to
  # * :dir  directory to download source to, filename will be generated from the last part of the uri
   def download_to(args = {})
     # TODO handle source_type == git_repo

     path = args.has_key?(:path) ? args[:path] : nil
     dir  = args.has_key?(:dir)  ? args[:dir]  : nil

     # format the uri w/ any additional params
     format_uri! args

     begin
       # generate path which to d/l the file to
       fn = filename
       path = "#{dir}/#{fn}" if path.nil?
       dir  = File.dirname(path)
       raise ArgumentError unless File.writable?(dir)

       # d/l the file
       curl = Curl::Easy.new(uri)
       curl.follow_location = true # follow redirects
       curl.perform
       File.write path, curl.body_str

     rescue Exception => e
       raise RuntimeError, "could not download project source from #{uri} to #{path}"
     end

     return path
   end
end
