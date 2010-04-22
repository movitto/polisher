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

require 'lib/event_handlers'

class Event < ActiveRecord::Base
   include EventHandlers

   belongs_to :project

   validates_presence_of :project_id
   validates_presence_of :process

   # Dynamically generate from methods we define in the lib/event_handlers module.
   # Add more methods to that module for them to appear here
   def self.processes
     EventHandlers.public_instance_methods.collect { |m| m.to_s }
   end

   # XXX FIXME we need this for security
   #validates_inclusion_of :process, :in => Event.processes

   # Version qualifiers
   VERSION_QUALIFIERS = ['', '=', '>', '<', '>=', '<=']

   validates_inclusion_of :version_qualifier, :in => VERSION_QUALIFIERS, 
                          :if => Proc.new { |e| !e.version_qualifier.nil? }

   # nil version and version_qualifier indicates event will be run for _all_ versons

   validates_presence_of :version,
                         :if => Proc.new { |e| !e.version_qualifier.nil? }

   validates_presence_of :version_qualifier,
                         :if => Proc.new { |e| !e.version.nil? }

   # Determine if event applies to specified version
   def applies_to_version?(cversion)
     raise ArgumentError, "valid event version #{version} and version #{cversion} required" unless (version.nil? || version.class == String) && cversion.class == String

     # XXX remove any non-numeric chars from the version number (eg if a version has a '-beta' or whatnot, not pretty but works for now
     cversion.gsub(/[a-zA-Z]*/, '')

     # TODO this will evaluate to false "1.1" = "1.1.0" here, is this correct? (implement this in a more robust way, eg split version into array around delims, compare each array elements w/ special case handling)
     gv, ev = cversion, version
     return (["", nil].include? version_qualifier ) ||
            (version_qualifier == "="  && gv == ev) ||
            (version_qualifier == ">"  && gv >  ev) ||
            (version_qualifier == "<"  && gv <  ev) ||
            (version_qualifier == ">=" && gv >= ev) ||
            (version_qualifier == "<=" && gv <= ev)
   end

   # Run the event, :version should be passed in via args; any other keys/values are optional
   # and will be forwarded onto the event handler
   def run(args = {})
      version = args[:version]
      raise ArgumentError, "must specify version when running event" if version.nil?

      handler = nil
      begin
        # covert process to method name
        handler = method(process.intern)
      rescue NameError => e
        raise ArgumentError, "could not find event handler #{process}"
      end

      # generate array of event params from project, the event itself, the version being run, and any optional params passed in
      event_params  = [self, version, args]

      begin
        # invoke
        handler.call *event_params
      rescue Exception => e
        raise RuntimeError, "error when running event handler #{process}: #{e}"
      end
   end
end
