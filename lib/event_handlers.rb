# Gem event handler callbacks,
# A method should exist here for every process supported by the system.
# Once added to this module it will automatically appear in
# db/models/Event::processes for subsequent use.
#
# Each method should take three parameters
# * the event being run
# * the version of the project being released
# * any additional event-specific arguments in an optional hash
#
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

require 'erb'
require 'gem2rpm'
require 'net/smtp'

# TODO raise some exceptions of our own here (though not neccessary as event.run will rescue everything raised, it might help w/ debugging)

module EventHandlers

# Convert project into rpm package format.
def create_rpm_package(event, version, args = {})
   project       = event.project
   template_file = event.process_options

   # open a handle to the spec file to write
   spec_file = ARTIFACTS_DIR + "/SPECS/#{project.name}.spec"
   sfh = File.open(spec_file, "wb")

   # d/l projects sources into artifacts/SOURCES dir
   args.merge!({ :dir => ARTIFACTS_DIR + "/SOURCES", :version => version })
   project.download_to args

   # read template if specified
   template = (template_file == '' || template_file.nil?) ? nil : File.read_all(template_file)

   # if primary project source is a gem, process template w/ gem2rpm
   primary_source = project.primary_source_for_version(version)
   if !primary_source.nil? && primary_source.source_type == "gem"
     gem_file_path = ARTIFACTS_DIR + '/SOURCES/' + primary_source.filename
     template = Gem2Rpm::TEMPLATE if template.nil?
     Gem2Rpm::convert gem_file_path, template, sfh

   # otherwise just process it w/ erb
   else
     # setting local variables to be pulled into erb via binding below
     params_s = ''
     args.each { |k,v| params_s += "#{k} = '#{v}' ; " }
     eval params_s

     # setting other local variables
     name = project.name
     # version is already set from above

     # take specified template_file and process it w/ erb,
     # TODO raise exception if we don't have a template
     template = File.read_all(template_file)
     template = ERB.new(template, 0, '<>').result(binding)

     # write to spec_file
     sfh.write template

   end

   sfh.close

   # run rpmbuild on spec
   system("rpmbuild --define '_topdir #{ARTIFACTS_DIR}' -ba #{spec_file}")

   # XXX FIXME this need to record all the rpms actually created
end

# Update specified yum repository w/ latest project artifact for specified version
def update_yum_repo(event, version, args = {})
   project    = event.project
   repository = event.process_options

   # create the repository dir if it doesn't exist
   Dir.mkdir repository unless File.directory? repository

   # XXX FIXME this need to copy all the rpms created, including all that don't match the project name

   # get the latest built rpm that matches the project name
   project_src_rpm = Dir[ARTIFACTS_DIR + "/RPMS/*/#{project.name}-#{version}*.rpm"].
                             collect { |fn| File.new(fn) }.
                             sort { |f1,f2| f1.mtime <=> f2.mtime }.last
   project_tgt_rpm = "#{project.name}.rpm"

   # grab the architecture from the directory the src file resides in
   project_arch = project_src_rpm.path.split('.')
   project_arch = project_arch[project_arch.size-2]

   # copy project into repo/arch dir, creating it if it doesn't exist
   arch_dir = repository + "/#{project_arch}"
   Dir.mkdir arch_dir unless File.directory? arch_dir
   File.write(arch_dir + "/#{project_tgt_rpm}", project_src_rpm.read)

   # run createrepo to finalize the repository
   system("createrepo #{repository}")
end

end #module EventHandlers
