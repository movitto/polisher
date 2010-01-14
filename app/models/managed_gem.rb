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

# Gem representation in polisher, associated w/ rubygem being
# managed, used to track updates and invoke handlers
class ManagedGem < ActiveRecord::Base
   belongs_to :gem_source
   has_many :event_handlers
   alias :source :gem_source

   validates_presence_of   :name, :version, :gem_source_id
   validates_uniqueness_of :name, :scope => :gem_source_id

   # FIXME add validation to verify gem can be found in the associated gem source

   # helper, get gem uri
   def uri
      gem_source.uri + "/gems/" + name + "-" + version + ".gem"
   end

   # subscribe to updates to this gem from the associated gem source
   def subscribe(args = {})
        callback_url = args[:callback_url]

        logger.info ">> subscribting to updates to gem #{name} hosted at #{gem_source.uri}"
        GemApiAdapter.subscribe(:api_uri      => gem_source.uri, 
                                :api_key      => POLISHER_CONFIG["gem_api_key"],
                                :gem_name     => name,
                                :callback_url => callback_url,
                                :logger       => logger)
   end
end
