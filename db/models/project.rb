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

class Project < ActiveRecord::Base
  # TODO on delete, destroy these
  has_many :project_source_versions
  has_many :sources, :through => :project_source_versions
  has_many :events

  has_many :project_dependencies
  has_many :project_dependents, :class_name => "ProjectDependency", :foreign_key => "depends_on_project_id"

  alias :dependencies :project_dependencies
  alias :dependents :project_dependents

  validates_presence_of   :name
  validates_uniqueness_of :name

  # Download all project sources to specified :dir
  def download_to(args = {})
    # If a version isn't specified we can't lookup project_source_versions entry for uri substitutions
    # FIXME the latter case in this ternary operator should be something along the lines of sources_for_all_versions returning those only associated w/ project_version = nil (also being sure to do uri_params substition) (?)
    srcs = args.has_key?(:version) ? sources_for_version(args[:version]) : sources
    srcs.each { |source| source.download_to args }
  end

  # Return all events associated w/ particular version of the project
  def events_for_version(version)
    evnts = events
    evnts.find_all { |event| event.applies_to_version?(version) }
  end

  # Return all dependencies associated w/ particular version of the project
  def dependencies_for_version(version)
    deps = project_dependencies
    deps.find_all { |dep| dep.project_version == version || dep.project_version.nil? }
  end

  # Return all project_source_versions associated w/ particular version of the project
  def project_source_versions_for_version(version)
    psa = project_source_versions
    psa.find_all { |ps| ps.project_version == version || ps.project_version.nil? }
  end

  # Return all sources associated w/ particular version of the project, each w/ uri formatted
  # using project_source_versions source_uri_params
  def sources_for_version(version)
    project_source_versions_for_version(version).collect { |ps|
      ps.source.format_uri!(ps.source_uri_params)
      ps.source
    }
  end

  # Get the project primary source
  def primary_source
    ps = project_source_versions.all.find { |ps| ps.primary_source }
    # TODO special case if no sources are marked as primary, grab the first ? (also in primary_source_for_version below)
    return ps.nil? ? nil : ps.source
  end

  # Set the project primary source
  def primary_source=(source)
    project_source_versions << ProjectSourceVersion.new(:project => self, :source => source, :primary_source => true)
    #source.save! ; save!
  end

  # Return the primary source for the specified version
  def primary_source_for_version(version)
    ps = project_source_versions_for_version(version).find { |ps| ps.primary_source }
    ps.source.format_uri!(ps.source_uri_params) unless ps.nil?
    return ps.nil? ? nil : ps.source
  end

  # Return all versions which we have configured this project for
  def versions
    # TODO should we return configured project_depents.depends_on_project_version as well ?
    (project_source_versions.collect { |ps| ps.project_version } +
     events.collect { |e| e.version } +
     project_dependencies.collect { |d| d.project_version }).uniq - [nil]
  end

  # Release specified project version
  def released_version(version, args = {})
    # process dependencies
    dependencies_for_version(version).each { |dep|
      dargs = {}
      dargs = dep.depends_on_project_params.to_h.merge!(args) unless dep.depends_on_project_params.nil?

      # if dep_version.nil? grab all configured depends_on_project versions
      dep_versions = dep.depends_on_project_version
      dep_versions = dep_versions.nil? ? dep.depends_on_project.versions : [dep_versions]

      dep_versions.each { |dv| dep.depends_on_project.released_version(dv, dargs) }
    }

    # process events
    args[:version] = version
    events_for_version(version).each { |event| event.run(args) }
  end

end
