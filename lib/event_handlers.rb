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

require 'gem2rpm'
require 'net/smtp'

# Convert gem into another package format.
# Right now uses gem2rpm to create rpm spec, taking optional template file name
# TODO extend/modify to support any other output package format
# TODO add support for creating project package (manaully subin params to source uri's and process ERB template like gem2rpm), add optional params here
def create_package(entity, process_options = [''], optional_params = {})
   gem = entity
   template_file = process_options[0]

   # d/l gem into artifacts/gems dir, link it into the artifacts/SOURCES dir
   gem_file_path = gem.download_to :dir => ARTIFACTS_DIR + "/gems"
   gem_file = gem_file_path.split('/').last
   File.symlink gem_file_path, ARTIFACTS_DIR + "/SOURCES/" + gem_file

   # spec we are writing
   spec_file = ARTIFACTS_DIR + "/SPECS/rubygem-#{gem.name}.spec"
   sfh   = File.open(spec_file, "wb")

   # coversion template to use, if not specified use gem2rpm default
   template = Gem2Rpm::TEMPLATE
   File.open(ARTIFACTS_DIR + "/templates/#{template_file}", "rb") { |file| 
       template = file.read 
   } unless template_file == '' || template_file.nil?

   # create rpm spec w/ gem2rpm
   Gem2Rpm::convert gem_file_path, template, sfh
   sfh.close

   # run rpmbuild on spec
   system("rpmbuild --define '_topdir #{ARTIFACTS_DIR}' -ba #{spec_file}")
end

# Update specified repository w/ latest gem artifact.
# Right now updates specified yum repo w/ newly created gem rpm
# TODO extend/modify to support other repository formats
# TODO add support for adding project packages to repo
def update_repo(entity, process_options, optional_params = {})
   gem = entity
   repository = process_options[0]

   # create the repository dir if it doesn't exist
   repo_dir = ARTIFACTS_DIR + "/repos/#{repository}"
   Dir.mkdir repo_dir unless File.directory? repo_dir

   # get the latest built rpm that matches gem name 
   # FIXME need to incorporate version
   gem_file = Dir[ARTIFACTS_DIR + "/RPMS/*/rubygem-#{gem.name}-*.rpm"].
                             collect { |fn| File.new(fn) }.
                             sort { |f1,f2| file1.mtime <=> file2.mtime }.last

   # grab the architecture from the directory the file resides in  
   arch = gem_file.path.split('.')
   arch = arch[arch.size-2]

   # copy gem into repo/arch dir, creating it if it doesn't exist
   arch_dir = repo_dir + "/#{arch}" 
   Dir.mkdir arch_dir unless File.directory? arch_dir
   File.open(arch_dir + "/rubygem-#{gem.name}.rpm", 'wb') { |ofile| ofile.write gem_file.read }

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
