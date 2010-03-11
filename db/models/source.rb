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

# Source represents a remote endpoint which we will use
# the gem API to get gems / subscribe to updates
class Source < ActiveRecord::Base
   has_many :managed_gems

   alias :gems :managed_gems

   validates_presence_of :name
   validates_presence_of :uri
   validates_uniqueness_of :name
   validates_uniqueness_of :uri

   # TODO validate format of uri

   # TODO should have additional validation method that contacts gem source uri and 
   # makes sure it satisfiest gem API requests
   
   # remove trailing slash in uri if present
   before_save :clean_uri!
   def clean_uri!
     self.uri = self.uri[0...self.uri.size-1] if self.uri[-1].chr == '/'
   end
end
