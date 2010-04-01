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

class Event < ActiveRecord::Base
   belongs_to :managed_gem
   alias :gem :managed_gem

   belongs_to :project

   validates_presence_of   :process

   validates_presence_of :managed_gem_id, :if => Proc.new { |e| e.project_id.nil? }
   validates_presence_of :project_id, :if => Proc.new { |e| e.managed_gem_id.nil? }
   # TODO also need the XOR condition, eg both can't be set at the same time

   # TODO right mow just returning a fixed list, at some point dynamically generate
   def self.processes
      ["create_package", "update_repo", "run_test_suite", "notify_subscribers"]
   end

   # XXX FIXME we need this for security
   #validates_inclusion_of :process, :in => Event.processes

   #  version qualifiers
   VERSION_QUALIFIERS = ['', '=', '>', '<', '>=', '<=']

   validates_inclusion_of :version_qualifier, :in => VERSION_QUALIFIERS, 
                          :if => Proc.new { |e| !e.version_qualifier.nil? }

   # TODO change name of this column to 'version'
   validates_presence_of :gem_version,
                         :if => Proc.new { |e| !e.version_qualifier.nil? }

   validates_presence_of :version_qualifier,
                         :if => Proc.new { |e| !e.gem_version.nil? }

   # determine if event applies to specified version
   def applies_to_version?(version)
     # TODO this will evaluate to false "1.1" = "1.1.0" here, is this correct?, what about other version schemes (beta, patch# etc)
     gv, ev = version, gem_version
     return (["", nil].include? version_qualifier ) ||
            (version_qualifier == "="  && gv == ev) ||
            (version_qualifier == ">"  && gv >  ev) ||
            (version_qualifier == "<"  && gv <  ev) ||
            (version_qualifier == ">=" && gv >= ev) ||
            (version_qualifier == "<=" && gv <= ev)
   end

   # run the event
   def run(params = {})
      # covert process to method name
      handler = method(process.intern)

      entity = gem
      entity = project if entity.nil?

      # generate array of event params from gem/project, semi-colon seperated process options, and options params
      event_params  = [entity, (process_options.nil? ? [] : process_options.split(';')), params]

      # invoke
      handler.call *event_params
   end
end
