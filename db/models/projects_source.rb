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

# FIXME rename to ProjectSourceVersion

class ProjectsSource < ActiveRecord::Base
  belongs_to :project
  belongs_to :source

  # FIXME destroy source on deletion only if no other projects_sources sharing the source exist

  validates_uniqueness_of :source_id, :scope => [:project_id, :project_version]

  # validate only one primary_source set to 'true' in scope of (project_id, project_version)
  validates_uniqueness_of :primary_source,
                          :scope => [:project_id, :project_version],
                          :if    => Proc.new { |ps| ps.primary_source }

  before_save :normalize_versions
  def normalize_versions
    self.project_version = nil if project_version == ""
    self.source_version = nil if source_version == ""
  end
end
