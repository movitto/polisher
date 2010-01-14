#
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

# Currently handles gemcutter api callback invocations
class CallbackController < ApplicationController
  layout nil

  # invoked when a gem is updated on a remote source
  def gem_updated
     name    = params[:name]
     # XXX bit of a dirty hack needed as this is the only way to get source_uri
     source_uri = GemApiAdapter.gem_to_source_uri(params[:gem_uri]) 
     logger.info ">> gem #{name} hosted at #{source_uri} has been updated"

     # find the managed gem which was updated, invoke gem_updated event handlers
     gem_source = GemSource.find(:first, :conditions => ["uri = ?", source_uri])
     gem = gem_source.gems.all.find { |gem| gem.name == name }
     logger.info ">> found corresponding managed gem #{gem.name}"

     # update gem attributes
     gem_data = GemApiAdapter.gem_info :api_uri => gem_source.uri, 
                                       :gem_name => gem.name, 
                                       :logger => logger
     gem.version = gem_data["version"]
     gem.save!

     gem.event_handlers.find_all { |eh| eh.event == "gem_updated" }.each { |eh|
        eh.run
     }
  end
end
