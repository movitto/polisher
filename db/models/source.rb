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
  def filename(variables = {})
    turi = uri
    variables.each { |k,v| turi.gsub!("%{#{k}}", v.to_s) }
    URI::parse(turi).path.split('/').last
  end

  # Download source, args may contain any of the following
  # * :path path to download source to
  # * :dir  directory to download source to, filename will be generated from the last part of the uri
  # * :variables hash of key/value pairs to subsitute into the uri
   def download_to(args = {})
     # TODO handle source_type == git_repo

     path = args.has_key?(:path) ? args[:path] : nil
     dir  = args.has_key?(:dir)  ? args[:dir]  : nil
     variables = args.has_key?(:variables) ? args[:variables] : {}

     # swap in any specified variables into uri
     turi = uri
     variables.each { |k,v| turi.gsub!("%{#{k}}", v.to_s) }

     begin
       # generate path which to d/l the file to
       fn = filename(variables)
       path = "#{dir}/#{fn}" if path.nil?
       dir  = File.dirname(path)
       raise ArgumentError unless File.writable?(dir)

       # d/l the file
       curl = Curl::Easy.new(turi)
       curl.follow_location = true # follow redirects
       curl.perform
       File.write path, curl.body_str

     rescue Exception => e
       raise RuntimeError, "could not download project source from #{turi} to #{path}"
     end

     return path
   end
end
