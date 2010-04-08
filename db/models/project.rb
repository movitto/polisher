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
  has_many :projects_sources
  has_many :sources, :through => :projects_sources

  has_many :events

  validates_presence_of   :name
  validates_uniqueness_of :name

  # Download all project sources to specified :dir
  def download_to(args = {})
    sources.each { |source| source.download_to args }
  end

  # Get the project primary source
  def primary_source
    ps = projects_sources.all.find { |ps| ps.primary_source }
    return ps.nil? ? nil : ps.source
  end

  # Set the project primary source
  def primary_source=(source)
    projects_sources << ProjectsSource.new(:project => self, :source => source, :primary_source => true)
    #source.save! ; save!
  end
end
