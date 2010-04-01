# Gem event handler callbacks,
# A method should exist here for every process supported by the system.
# Each method should share the same name w/ the corresponding process.
# Each method should take three parameters the gem/project which the event is being run on,
#  an array of process options associated w/ the event, and a hash of any parameter names/values
#  passed in when the event is invoked.
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

# Convert entity (gem, project) into another package format.
# TODO rename to create_rpm_package
def create_package(entity, process_options = [''], optional_params = {})
   template_file = process_options[0]
   spec_file = nil

   if entity.class == ManagedGem
     # d/l gem into artifacts/gems dir, link it into the artifacts/SOURCES dir
     gem_file_path = entity.download_to :dir => ARTIFACTS_DIR + "/gems"
     gem_file = gem_file_path.split('/').last
     File.symlink gem_file_path, ARTIFACTS_DIR + "/SOURCES/" + gem_file

     # spec we are writing
     spec_file = ARTIFACTS_DIR + "/SPECS/rubygem-#{entity.name}.spec"
     sfh   = File.open(spec_file, "wb")

     # coversion template to use, if not specified use gem2rpm default
     template = Gem2Rpm::TEMPLATE
     File.open(ARTIFACTS_DIR + "/templates/#{template_file}", "rb") { |file|
         template = file.read
     } unless template_file == '' || template_file.nil?

     # create rpm spec w/ gem2rpm
     Gem2Rpm::convert gem_file_path, template, sfh
     sfh.close

   elsif entity.class == Project
     # d/l projects sources into artifacts/SOURCES dir
     entity.download_to :dir => ARTIFACTS_DIR + "/SOURCES", :variables => optional_params

     # spec we are writing
     spec_file = ARTIFACTS_DIR + "/SPECS/#{entity.name}.spec"

     # take specified template_file and process it w/ erb,
     # TODO raise exception if we don't have a template
     template = nil
     File.open(template_file, "rb") { |file|
       # run through the optional params,
       # setting local variables to be pulled in via binding below
       params_s = ''
       optional_params.each { |k,v| params_s += "#{k} = '#{v}' ; " }
       eval params_s

       template = file.read
       template = ERB.new(template, 0, '<>').result(binding)
     }

     # write to spec_file
     File.write spec_file, template
   end

   # run rpmbuild on spec
   system("rpmbuild --define '_topdir #{ARTIFACTS_DIR}' -ba #{spec_file}")
end

# Update specified repository w/ latest entity (gem, project) artifact.
# TODO rename to update_yum_repo
def update_repo(entity, process_options, optional_params = {})
   repository = process_options[0]

   # create the repository dir if it doesn't exist
   repo_dir = ARTIFACTS_DIR + "/repos/#{repository}"
   Dir.mkdir repo_dir unless File.directory? repo_dir

   prefix = entity.class == ManagedGem ? 'rubygem-' : ''
   # get the latest built rpm that matches gem name 
   # FIXME need to incorporate version
   entity_src_rpm = Dir[ARTIFACTS_DIR + "/RPMS/*/#{prefix}#{entity.name}-*.rpm"].
                             collect { |fn| File.new(fn) }.
                             sort { |f1,f2| file1.mtime <=> file2.mtime }.last
   entity_tgt_rpm = "#{prefix}#{entity.name}.rpm"

   # grab the architecture from the directory the src file resides in
   entity_arch = entity_src_rpm.path.split('.')
   entity_arch = entity_arch[entity_arch.size-2]

   # copy entity into repo/arch dir, creating it if it doesn't exist
   arch_dir = repo_dir + "/#{entity_arch}"
   Dir.mkdir arch_dir unless File.directory? arch_dir
   File.open(arch_dir + "/#{entity_tgt_rpm}", 'wb') { |ofile| ofile.write entity_src_rpm.read }

   # run createrepo to finalize the repository
   system("createrepo #{repo_dir}")
end

# run gem's test suite against specified repository
def run_test_suite(entity, process_options, optional_params = {})
end

# notify a list of recipients of gem update
def notify_subscribers(entity, process_options, optional_params = {})
    gem = entity
    recipients = process_options

    from    = POLISHER_CONFIG['email_from']
    subject = POLISHER_CONFIG['email_subject']
    body    = POLISHER_CONFIG['email_body']
    server =  POLISHER_CONFIG['email_server']

    # substitute variables into subject / body where appropriate
    subject.gsub('#{gem_name}', gem.name)
    body.gsub('#{gem_name}', gem.name)

    msg = <<END_OF_MESSAGE
From: #{from}
To: #{recipients.join(',')}
Subject: #{subject}

#{body}
END_OF_MESSAGE
    
   Net::SMTP.start(server) do |smtp|
       smtp.send_message msg, from, to
   end 
end
