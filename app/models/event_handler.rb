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

# EventHandler refers to a Gem, and specified event enumeration value,
# and event handler enumeration value.
# Currently both events / handlers are pretty static / hard coded into
# this system, but this may change in the future.
class EventHandler < ActiveRecord::Base
   belongs_to :managed_gem
   alias :gem :managed_gem

   validates_presence_of :managed_gem_id, :event, :handler
   validates_uniqueness_of :handler, :scope => [:managed_gem_id, :event]

   def name
     gem.name.to_s + ":" + @event.to_s + ":" + @handler.to_s
   end

   # FIXME right now hard coding and dispatching 
   # specific events / handlers here, at some point
   # replace w/ something more dynamic / plugable
   EVENTS   = [:gem_created,:gem_updated]
   HANDLERS = [:send_email, :build_rpm, :submit_rpm]

   # dispatch to correct handler upon event
   def run
      logger.info ">> running #{event} handler #{handler} for gem #{gem.name}"
      case(handler)
        when "send_email"
           EmailAdapter.send_email(:server  => POLISHER_CONFIG["smtp_server"],
                                   :from    => POLISHER_CONFIG["email_from"],
                                   :to      => POLISHER_CONFIG["email_to"],
                                   :subject => "gem #{gem.name} event #{event}",
                                   :logger  => logger)
        when "build_rpm"
           # FIXME create artifact
           RpmAdapter.build(:gem => gem, :logger => logger)
        when "submit_rpm"
           #if @event == :gem_created
           # rpm = RPMEventHandler.build(@managed_gem)
           # RPMEventHandler.submit(rpm)
           #end
      end
   end

end
