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

class ProjectDependency < ActiveRecord::Base
  belongs_to :project
  belongs_to :depends_on_project, :class_name => "Project", :foreign_key => "depends_on_project_id"

  validates_presence_of :project_id
  validates_presence_of :depends_on_project_id

  validates_uniqueness_of :depends_on_project_version, :scope => [:project_id, :depends_on_project_id, :depends_on_project_version]

  before_save :normalize_versions
  def normalize_versions
    self.project_version = nil if project_version == ""
    self.depends_on_project_version = nil if depends_on_project_version == ""
  end
end
