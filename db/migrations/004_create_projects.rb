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

class CreateProjects < ActiveRecord::Migration
  def self.up
    create_table :projects do |t|
      t.string :name
    end

    create_table :project_sources do |t|
      t.string :uri
      t.references    :project
    end

    add_column :events, :project_id, :integer
  end

  def self.down
    remove_column :events, :project_id
    drop_table :project_sources
    drop_table :projects
  end
end
