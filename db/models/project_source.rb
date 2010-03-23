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

class ProjectSource < ActiveRecord::Base
  belongs_to :project

  validates_presence_of :project_id
  validates_presence_of :uri

  validates_uniqueness_of :uri, :scope => :project_id

  # Download all project sources to specified :path or :dir
   def download_to(args = {})
     path = args.has_key?(:path) ? args[:path] : nil
     dir  = args.has_key?(:dir)  ? args[:dir]  : nil

     urio = URI::parse(uri)
     path = dir + "/" + urio.path.split('/').last if path.nil?

     curl = Curl::Easy.new(uri)
     curl.follow_location = true # follow redirects
     curl.perform
     File.write path, curl.body_str

     return path
   end
end
