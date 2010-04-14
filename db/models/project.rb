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
  has_many :projects_sources
  has_many :sources, :through => :projects_sources
  has_many :events

  validates_presence_of   :name
  validates_uniqueness_of :name

  # Download all project sources to specified :dir
  def download_to(args = {})
    # If a version isn't specified we can't lookup projects_sources entry for uri substitutions
    # FIXME the latter case in this ternary operator should be something along the lines of sources_for_all_versions returning those only associated w/ project_version = nil (also being sure to do uri_params substition) (?)
    srcs = args.has_key?(:version) ? sources_for_version(args[:version]) : sources
    srcs.each { |source| source.download_to args }
  end

  # Return all events associated w/ particular version of the project
  def events_for_version(version)
    evnts = events
    evnts.find_all { |event| event.applies_to_version?(version) }
  end

  # Return all projects_sources associated w/ particular version of the project
  def projects_sources_for_version(version)
    psa = projects_sources
    psa.find_all { |ps| ps.project_version == version || ps.project_version.nil? }
  end

  # Return all sources associated w/ particular version of the project, each w/ uri formatted
  # using projects_sources source_uri_params
  def sources_for_version(version)
    projects_sources_for_version(version).collect { |ps|
      ps.source.format_uri!(ps.source_uri_params)
      ps.source
    }
  end

  # Get the project primary source
  def primary_source
    ps = projects_sources.all.find { |ps| ps.primary_source }
    # TODO special case if no sources are marked as primary, grab the first ? (also in primary_source_for_version below)
    return ps.nil? ? nil : ps.source
  end

  # Set the project primary source
  def primary_source=(source)
    projects_sources << ProjectsSource.new(:project => self, :source => source, :primary_source => true)
    #source.save! ; save!
  end

  # Return the primary source for the specified version
  def primary_source_for_version(version)
    ps = projects_sources_for_version(version).find { |ps| ps.primary_source }
    ps.source.format_uri!(ps.source_uri_params) unless ps.nil?
    return ps.nil? ? nil : ps.source
  end

  # Return all versions which we have configured this project for
  def versions
    (projects_sources.collect { |ps| ps.project_version } +
     events.collect { |e| e.version }).uniq - [nil]
  end
end
