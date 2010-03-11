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

class CreateSources < ActiveRecord::Migration
  def self.up
    create_table :sources do |t|
      t.string :name
      t.string :uri
    end

    # create entry for the official gemcutter repo
    Source.create :name => "gemcutter", :uri => "http://gemcutter.org"
  end

  def self.down
    drop_table :sources
  end
end
