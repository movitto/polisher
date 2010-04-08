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

# Need this class since attributes are defined on the relationship
# http://robots.thoughtbot.com/post/159808010/rails-has-and-belongs-to-many-conveniences
class ProjectsSource < ActiveRecord::Base
  belongs_to :project
  belongs_to :source

  # TODO validate primary_source is only set true for once
  # source per project

  # TODO default primary_source to false
end
