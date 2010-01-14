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

# Currently handles all user based actions, including CRUDing
# the user controlled model entities / fields
class ManageController < ApplicationController
  def list
     @gem_sources = GemSource.find :all
  end

  ############################ gem sources

  def new_gem_source
  end

  def create_gem_source
     name = params[:name]
     uri  = params[:uri]
     @gem_source = GemSource.new :name => name, :uri => uri
     @error = nil
     @gem_source.save!
     rescue Exception => e
       @error = e
  end

  def delete_gem_source
     id = params[:id]
     @name = GemSource.find(id).name
     GemSource.delete id
     @error = nil
  end

  ############################ managed gems

  def new_gem
     @gem_source_id = params[:gem_source_id]
     @gem_sources   = GemSource.find :all
  end

  def create_gem
     gem_source_id = params[:gem_source_id]
     name          = params[:name]
     version       = params[:version]
     @gem = ManagedGem.new :name => name, :version => version, :gem_source_id => gem_source_id
     @error = nil

     # save gem / subscribe to updates
     # FIXME these two steps should be in a transaction
     @gem.save!
     @gem.subscribe :callback_url => url_for(:controller => :callback, :action => :gem_updated)
     rescue Exception => e
       @error = e
  end

  def delete_gem
     id = params[:id]
     @name = ManagedGem.find(id).name
     ManagedGem.delete id
     @error = nil
  end

  ############################ gem search criterias

  def new_gem_search_criteria
     @gem_source_id = params[:gem_source_id]
     @gem_sources   = GemSource.find :all
  end

  ############################ event handlers

  def new_event_handler
     @gem_id = params[:gem_id]
     @gems   = ManagedGem.find :all
     @events   = EventHandler::EVENTS
     @handlers = EventHandler::HANDLERS
  end

  def create_event_handler
     gem_id  = params[:gem_id]
     event   = params[:event]
     handler = params[:handler]
     @event_handler = EventHandler.new :managed_gem_id => gem_id, :event => event, :handler => handler
     @error = nil
     @event_handler.save!
     rescue Exception => e
       @error = e
  end

  def delete_event_handler
     id = params[:id]
     @name = EventHandler.find(id).name
     EventHandler.delete id
     @error = nil
  end

end
