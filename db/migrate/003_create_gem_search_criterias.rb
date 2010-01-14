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

# according to google the plural for "criteria" is "criterion"
# but the active_support inflector begs to differ and I'm not gonna argue :-)
class CreateGemSearchCriterias < ActiveRecord::Migration
  def self.up
    create_table :gem_search_criterias do |t|
      t.string      :regex
      t.references  :gem_source
    end
  end

  def self.down
    drop_table :gem_search_criterias
  end
end
