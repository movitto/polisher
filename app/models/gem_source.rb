# Copyright (C) 2010 Red Hat, Inc.
# Written by Mohammed Morsi <mmorsi@redhat.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.  A copy of the GNU General Public License is
# also available at http://www.gnu.org/copyleft/gpl.html.

# GemSource represents a remote endpoint which we will use
# the gem API to get gems from / subscribe to updates
class GemSource < ActiveRecord::Base
   has_many :managed_gems
   has_many :gem_search_criterias

   alias :gems :managed_gems
   alias :searches :gem_search_criterias

   validates_presence_of :name
   validates_presence_of :uri
   validates_uniqueness_of :name
   validates_uniqueness_of :uri

   # FIXME validate format of uri

   # FIXME should have additional validation method that contacts gem source uri and 
   # makes sure it satisfiest gem API requests
   
   # remove trailing slash in uri if present
   before_save :clean_uri
   def clean_uri
     self.uri = self.uri[0...self.uri.size-1] if self.uri[-1].chr == '/'
   end
end
