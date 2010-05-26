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
# FIXME way better reporting / logging, if rpm, mock, or yum build fails, we need logs

module EventHandlers

# Download project sources
def download_sources(event, version, args = {})
   project       = event.project
   args.merge!({ :dir => ARTIFACTS_DIR + "/SOURCES", :version => version })
   args = event.process_options.to_h.merge(args) unless event.process_options.nil?

   # if we've already d/l'd the sources, skip the rest of the event execution (incorporate md5sums in the future)
   downloaded = true
   project.sources_for_version(version).each { |src|
     src.format_uri! args
     downloaded = false unless File.exists?(ARTIFACTS_DIR + "/SOURCES/#{src.filename}")
   }
   return if downloaded

   # d/l projects sources into artifacts/SOURCES dir
   project.download_to args
end

# Convert project into rpm package format.
def create_rpm_package(event, version, args = {})
   project       = event.project
   args.merge!({ :version => version })
   template_file = nil
   mock_target = nil

   unless event.process_options.nil?
     poh = event.process_options.to_h
     template_file = poh["spec"]
     mock_target = poh["mock"]
     args.merge!(poh)
   end

   # if the rpm is built, skip the rest of the event execution (really need to check if the sources changed)
   return if !Dir[ARTIFACTS_DIR + "/RPMS/*/#{project.name}-#{version}*.rpm"].empty?

   # open a handle to the spec file to write
   spec_file = ARTIFACTS_DIR + "/SPECS/#{project.name}.spec"
   sfh = File.open(spec_file, "wb")

   # read template if specified
   template = (template_file == '' || template_file.nil?) ? nil : File.read_all(template_file)

   # if primary project source is a gem, process template w/ gem2rpm
   primary_source = project.primary_source_for_version(version)
   if !primary_source.nil? && primary_source.source_type == "gem"
     primary_source.format_uri! args
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

   # FIXME we need to handle the return code of these next two system commands,
   # if not success, throw an exception

   # run rpmbuild on spec to build srpm
   system("rpmbuild --define '_topdir #{ARTIFACTS_DIR}' -bs #{spec_file}")

   # run mock on srpm to build rpm
   system("mock -r #{mock_target} rebuild #{ARTIFACTS_DIR}/SRPMS/#{project.name}-#{version}*.src.rpm")

   # copy generated rpms from /var/lib/mock/[mock_root] to ARTIFACTS/RPMS/[arches]
   Dir["/var/lib/mock/#{mock_target}/root/builddir/build/RPMS/*.rpm"].each { |rpm|
     arch = rpm.split(".")
     arch = arch[arch.size-2]
     FileUtils.mkdir_p "#{ARTIFACTS_DIR}/RPMS/#{arch}" unless File.directory? "#{ARTIFACTS_DIR}/RPMS/#{arch}"
     FileUtils.cp rpm, "#{ARTIFACTS_DIR}/RPMS/#{arch}"
   }
end

# Update specified yum repository w/ latest project artifact for specified version
def update_yum_repo(event, version, args = {})
   project    = event.project
   repository = nil
   delete_rpms = false

   unless event.process_options.nil?
     poh = event.process_options.to_h
     repository = poh["repo"]
     delete_rpms = poh["delete_rpms"] == "true"
     args.merge!(poh)
   end

   # create the repository dir if it doesn't exist
   FileUtils.mkdir_p repository unless File.directory? repository

   packages = [project.name + "-" + version]

   # XXX real hacky way of getting all the packages corresponding to the project
   # FIXME need a better solution here as any macros in the package names won't get executed properly
   spec_file = ARTIFACTS_DIR + "/SPECS/#{project.name}.spec"
   packages += File.read_all(spec_file).scan(/%package.*/).collect { |p|
     ps = p.split
     prefix = ps[ps.size-2] == "-n" ? "" : (project.name + "-")
     prefix + p.split.last + "-" + version
   }

   # do not actually generate the repo unless a rpm is copied over
   updated_repo = false

   # copy the latest built rpms that match the packages
   packages.each { |pkg|
     pkg_file = Dir[ARTIFACTS_DIR + "/RPMS/*/#{pkg}*.rpm"].
                  collect { |fn| File.new(fn) }.
                  sort { |f1,f2| f1.mtime <=> f2.mtime }.last

     unless pkg_file.nil?
       # grab the architecture from the directory the src file resides in
       arch = pkg_file.path.split('.')
       arch = arch[arch.size-2]

       pkg_file_name = pkg_file.path.split('/').last

       # copy project into repo/arch dir, creating it if it doesn't exist
       arch_dir = repository + "/#{arch}"
       FileUtils.mkdir_p arch_dir unless File.directory? arch_dir
       unless File.exists?(arch_dir + "/#{pkg_file_name}") # TODO need to incorporate a md5sum comparison here
         updated_repo = true
         FileUtils.cp pkg_file.path, arch_dir + "/#{pkg_file_name}"
         FileUtils.rm_f pkg_file.path if delete_rpms # FIXME should do this deletion if delete_rpms is set regardless of whether or not we actually copy the rpms (?)
       end
     end
   }

   # run createrepo to finalize the repository
   system("createrepo #{repository}") if updated_repo
end

end #module EventHandlers
