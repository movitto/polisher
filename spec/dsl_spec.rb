# ruby gem polisher dsl spec
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

##########################
## target typical dsl use case:
#
# polisher "http://localhost:3000"
#
# project :name => "ruby" do |proj|
#  proj.add_archive :name => 'ruby_source', :uri => "ftp://ftp.ruby-lang.org/pub/ruby/%{rubyxver}/ruby-%{arcver}.tar.bz2" do |archive|
#    archive.version "1.8.6", :rubyxver => "1.8", :arcver => "1.8.7-p311", :corresponds_to => proj.version("1.8.6")
#    proj.version "1.9.1", :corresponds_to => archive.version("1.9.1", :rubyxver => "1.9", :arcver => "1.8.7-p300")
#  end
#  proj.add_patch "http://cvs.fedoraproject.org/viewvc/rpms/ruby/F-13/ruby-deadcode.patch?view=markup"
#  # etc...
#
#  proj.on_version "*", "create package"
#  proj.on_version "=",  "1.8.6",  "update repo", "stable"
#  proj.on_version ">=", "1.9.1",  "update repo", "devel"
# end
#
# project :name => "ruby-postgres" do |p|
# end
#
# project :name => "rubygem-rails" do |p|
#  p.add_gem "http://rubygems.org/gems/rails-%{version}.gem" do |g|
#    g.is_the_primary_source # instruct polisher to process this project w/ gem2rpm
#    g.version ..., :corresponds_to p.version ...
#  end
#
#  p.on_version "*", "create package"
#  p.on_version "<",  "2.0", "update repo", "legacy"
#  p.on_version "=",  "2.0", "update repo", "stable"
#  p.on_version ">=", "2.1", "update repo", "rawhide"
#
#  # etc....
# end
#
# project :name => 'my_project' do |p|
#  # ...
# end
#
######
## Test firing events
#project(:name => "ruby").released "1.8.6", :any => "other", :optional => "params"

require File.dirname(__FILE__) + '/spec_helper'

require 'thin'
require 'lib/dsl'

# start up the polisher server to handle rest requests
server = Thin::Server.new('127.0.0.1', 3000, app)
server_thread = Thread.new { server.start }

polisher "http://localhost:3000"

describe "Polisher::DSL::Project" do
   it "should accept members as constructor parameters" do
     proj = Polisher::Project.new :id => 20, :name => 'foobar'
     proj.id.should == 20
     proj.name.should == "foobar"

     Source::SOURCE_TYPES.each { |st|
       proj.method("add_#{st}".intern).should_not be_nil
     }
   end

   it "should be instantiatable from xml" do
     # TODO versions, sources, events
     xml = "<project><id>10</id><name>foo</name></project>"
     project = Polisher::Project.from_xml xml
     project.id.should   == 10
     project.name.should == "foo"
   end

  it "should return all projects" do
    proj1   = Project.create! :name => 'dsl-projects-test1'
    proj2   = Project.create! :name => 'dsl-projects-test2'
    test_projects = Project.all
    Project.find(:all).each { |proj|
      test_projects.find { |p| p.name == proj.name }.should_not be_nil
    }
  end

  it "should permit creating projects" do
    proj = Polisher::Project.new :name => 'project-creation-test'
    lambda {
      proj.create
    }.should change(Project, :count).by(1)
  end

  it "should raise and exception if project cannot be created" do
    proj = Project.create! :name => 'project-invalid-creation-test'
    proj = Polisher::Project.new :name => 'project-invalid-creation-test'
    lambda {
      proj.create
    }.should raise_error(RuntimeError)
  end

   it "should allow project deletions" do
     db_project = Project.create! :name => "project-event-deletion-test"
     project = Polisher::Project.new :id => db_project.id, :name => db_project.name
     lambda {
       project.delete
     }.should change(Project, :count).by(-1)
     lambda {
       Project.find(db_project.id)
     }.should raise_error(ActiveRecord::RecordNotFound)
   end

  it "should raise and exception if project cannot be deleted" do
    project = Polisher::Project.new :id => "abc"
    lambda {
      project.delete
    }.should raise_error(RuntimeError)
  end

   it "should allow event creations" do
     db_project = Project.create! :name => "project-event-creation-test"
     project    = Polisher::Project.new :id => db_project.id, :name => db_project.name
     lambda {
       project.on_version "<", "3.9", "do something", "options"
     }.should change(Event, :count).by(1)
     Event.find(:first, :conditions => [ 'project_id = ? AND version_qualifier = ? AND version = ? AND process = ? AND process_options = ?',
                                          project.id, "<", "3.9", "do_something", "options" ]).
                                          should_not be_nil
   end

   it "should correctly setup project/source versions" do
     proj = Project.create! :name => 'project-source-version-test-proj1'
     src =  Source.create!  :name => 'project-source-version-test-src1', :source_type => 'file', :uri => 'http://host.bar'

     proj1 = Polisher::Project.new :id => proj.id, :name => 'project-source-version-test-proj1'
     proj2 = proj1.version "1.9"
     proj2.should be(proj1)
     proj1.project_version.should == "1.9"

     src1 = Polisher::Source.new :id => src.id
     src1 = src1.version("2.0.12", :some => 'attr')

     lambda {
       proj1.version "1.6.5", :corresponds_to => src1
     }.should change(ProjectsSource, :count).by(1)

    ProjectsSource.find(:first, :conditions => ['project_version = ? AND source_version = ? AND project_id = ? AND source_id = ? AND source_uri_params = ?',
                                                "1.6.5", "2.0.12", proj.id, src.id, 'some=attr']).should_not be_nil
   end

   it "should trigger release" do
      db_project   = Project.create :name => 'dsl-trigger-test'
      event = Event.create :project => db_project,
                           :process => "integration_test_handler2",
                           :version_qualifier => '<',
                           :version => 1.0

      project = Polisher::Project.new :id => db_project.id, :name => db_project.name
      project.released 0.9
      $integration_test_handler_flags.include?(2).should == true
   end
end

describe "Polisher::DSL::Source" do
   it "should accept members as constructor parameters" do
     src = Polisher::Source.new(:id => 20, :name => 'foobar', :uri => 'http://foo.uri')
     src.id.should == 20
     src.name.should == "foobar"
     src.uri.should == "http://foo.uri"
   end

   it "should be instantiatable from xml" do
     # TODO versions, projects, events
     xml = "<source><id>10</id><name>foo</name><source_type>archive</source_type><uri>http://bar.uri</uri></source>"
     src = Polisher::Source.from_xml xml
     src.id.should   == 10
     src.name.should == "foo"
     src.source_type.should == "archive"
     src.uri.should  == "http://bar.uri"
   end

  it "should return all sources" do
      src1   = Source.create! :name => 'dsl-sources-test1', :source_type => 'patch', :uri => 'ftp://abc.def'
      src2   = Source.create! :name => 'dsl-sources-test2', :source_type => 'patch', :uri => 'http://111.222'
      test_sources = Source.all
      Source.find(:all).each { |src|
        test_sources.find { |s| s.name == src.name && s.type == src.type && s.uri == src.uri }.should_not be_nil
      }
  end

  it "should permit creating sources" do
    src = Polisher::Source.new(:name => 'project-creation-test', :source_type => 'archive', :uri => 'http://abc53')
    lambda {
      src.create
    }.should change(Source, :count).by(1)
  end

  it "should raise an exception if source cannot be created" do
    args = {:name => 'source-invalid-creation-test', :source_type => 'patch', :uri => 'ftp://invalid.source'}
    Source.create! args
    src = Polisher::Source.new args
    lambda {
      src.create
    }.should raise_error(RuntimeError)
  end

  it "should correctly setup project/source versions" do
    proj = Project.create! :name => 'project-source-version-test-proj41'
    src =  Source.create!  :name => 'project-source-version-test-src41', :source_type => 'file', :uri => 'http://bar.host.uri'

    src1 = Polisher::Source.new :id => src.id, :name => 'project-source-version-test-src41'
    src2 = src1.version "1.9", :some => "attr", :other => 'thing'
    src2.should be(src1)
    src1.source_version.should == "1.9"

    uri_args = src1.uri_args.split(";")
    uri_args.include?("some=attr").should be_true
    uri_args.include?("other=thing").should be_true

    proj1 = Polisher::Project.new :id => proj.id
    proj1 = proj1.version("2.0.12")

    lambda {
      src1.version "1.6.5", :some => "attr", :other => 'thing', :corresponds_to => proj1
    }.should change(ProjectsSource, :count).by(1)

    ps = ProjectsSource.find(:first, :conditions => ['source_version = ? AND project_version = ? AND project_id = ? AND source_id = ?',
                                                     "1.6.5", "2.0.12", proj.id, src1.id])
    ps.should_not be_nil
    uri_args = ps.source_uri_params.split(";")
    uri_args.include?("some=attr").should be_true
    uri_args.include?("other=thing").should be_true
  end
end


describe "Polisher::DSL" do
  it "should return all projects" do
    proj1   = Project.create! :name => 'dsl-projects-test100'
    proj2   = Project.create! :name => 'dsl-projects-test200'
    test_projects = projects
    Project.find(:all).each { |proj|
      test_projects.find { |p| p.name == proj.name }.should_not be_nil
    }
  end

  it "should find or create project" do
    test_project = nil
    lambda {
      test_project = project :name => "dsl-project-testc"
    }.should change(Project, :count).by(1)
    db_project = Project.find(:first, :conditions => ['name = ?', 'dsl-project-testc'])
    test_project.id.should == db_project.id

    lambda {
      test_project = project :name => "dsl-project-testc"
    }.should_not change(Project, :count)
    test_project.id.should == db_project.id
  end

  it "should return all sources" do
    source1   = Source.create! :name => 'dsl-sources-test51', :uri => "http://test1.host", :source_type => 'archive'
    source2   = Source.create! :name => 'dsl-sources-test52', :uri => "http://test2.host", :source_type => 'patch'
    test_sources = sources
    Source.find(:all).each { |source|
      test_sources.find { |s| s.name == source.name && s.uri == source.uri }.should_not be_nil
    }
    test_sources.find { |s| s.name == "dsl-sources-test51" && s.uri == "http://test1.host" && s.source_type == "archive" }.should_not be_nil
    test_sources.find { |s| s.name == "dsl-sources-test52" && s.uri == "http://test2.host" && s.source_type == "patch" }.should_not be_nil
  end

  it "should find or create source" do
    test_source = nil
    lambda {
      test_source = source :name => "dsl-source-test", :uri => "http://source.testc", :source_type => 'archive'
    }.should change(Source, :count).by(1)
    db_source = Source.find(:first, :conditions => ['name = ? AND uri = ? AND source_type = ?', 'dsl-source-test', 'http://source.testc', 'archive'])
    test_source.id.should == db_source.id

    lambda {
      test_source = source :name => "dsl-source-test", :uri => "http://source.testc"
    }.should_not change(Source, :count)
    test_source.id.should == db_source.id

    test_source = source :name => "dsl-source-test"
    test_source.id.should == db_source.id
  end

end

# prolly a better way todo this, but fine for now
$integration_test_handler_flags = []

def integration_test_handler1(entity, process_options = [], optional_params = {})
  $integration_test_handler_flags << 1
end

def integration_test_handler2(entity, process_options = [], optional_params = {})
  $integration_test_handler_flags << 2
end

# stop the sinatra server
#server.stop!
#server_thread.kill!
