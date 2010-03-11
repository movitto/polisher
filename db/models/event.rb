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

   validates_presence_of   :managed_gem_id, :process

   # TODO right mow just returning a fixed list, at some point dynamically generate
   def self.processes
      ["create_package", "update_repo", "run_test_suite", "notify_subscribers"]
   end

   #  version qualifiers
   VERSION_QUALIFIERS = ['', '=', '>', '<', '>=', '<=']

   validates_inclusion_of :version_qualifier, :in => VERSION_QUALIFIERS, 
                          :if => Proc.new { |e| !e.version_qualifier.nil? }

   validates_presence_of :gem_version,
                         :if => Proc.new { |e| !e.version_qualifier.nil? }

   validates_presence_of :version_qualifier,
                         :if => Proc.new { |e| !e.gem_version.nil? }

   # determine if event applies to specified version
   def applies_to_version?(version)
     gv, ev = version.to_f, gem_version.to_f
     return (["", nil].include? version_qualifier ) ||
            (version_qualifier == "="  && gv == ev) ||
            (version_qualifier == ">"  && gv >  ev) ||
            (version_qualifier == "<"  && gv <  ev) ||
            (version_qualifier == ">=" && gv >= ev) ||
            (version_qualifier == "<=" && gv <= ev)
   end

   # run the event
   def run
      # covert process to method name
      handler = method(process.intern)

      # generate array of params from semi-colon seperated options
      params  = process_options.nil? ? [] : process_options.split(';')

      # first param is always the gem
      params.unshift gem

      # invoke
      handler.call *params
   end
end
