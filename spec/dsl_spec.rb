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
#polisher "http://localhost:3000"
#
#source :name => "custom_source", :uri => "http://custom.source/"
#
#gem :name => 'myproject', :source => 'custom_source' { |g|
#  g.on_version "*", "create package"
#  g.on_version "<",  "2.0", "update repo", "legacy"
#  g.on_version "=",  "2.0", "update repo", "stable"
#  g.on_version ">=", "2.1", "update repo", "rawhide"
#}
#
#project :name => "official ruby" do |p|
#  p.add_source "ftp://ftp.ruby-lang.org/pub/ruby/%{rubyxver}/ruby-%{arcver}.tar.bz2"
#  p.add_source "http://cvs.fedoraproject.org/viewvc/rpms/ruby/F-13/ruby-deadcode.patch?view=markup"
#  # etc...
#  p.on_version "*", "create package"
#  p.on_version "=", "1.8.6", "update repo", "stable"
#  p.on_version ">=", "1.9",  "update repo", "devel"
#end
#
######
## Test firing events
#gem(:name => 'myproject').released "2.0"
#gem(:name => 'myproject').released "1.5"
#project(:name => "official ruby").released :rubyxver => '1.8', :arcver => '1.8.6-p388"

require File.dirname(__FILE__) + '/spec_helper'

require 'thin'
require 'lib/dsl'

# start up the polisher server to handle rest requests
server = Thin::Server.new('127.0.0.1', 3000, app)
server_thread = Thread.new { server.start }

polisher "http://localhost:3000"

describe "Polisher::DSL::ManagedGem" do
   it "should be instantiatable from xml" do
     xml = "<gem><id>10</id><name>foo</name><gem_source_id>20</gem_source_id></gem>"
     gem = Polisher::ManagedGem.from_xml xml
     gem.id.should   == 10
     gem.name.should == "foo"
     gem.gem_source_id.should  == 20
   end

   it "should allow event creations" do
     db_gem = ManagedGem.create! :name => "gem-event-creation-test", :gem_source_id => 1
     gem = Polisher::ManagedGem.new :id => db_gem.id, :name => db_gem.name
     lambda {
       gem.on_version ">=", "5.2", "do something", "options"
     }.should change(Event, :count).by(1)
     Event.find(:first, :conditions => [ 'managed_gem_id = ? AND version_qualifier = ? AND gem_version = ? AND process = ? AND process_options = ?',
                                          gem.id, ">=", "5.2", "do something", "options" ]).
                                          should_not be_nil
   end

   it "should allow gem deletion" do
     db_gem = ManagedGem.create! :name => "gem-event-deletion-test", :gem_source_id => 1
     gem = Polisher::ManagedGem.new :id => db_gem.id, :name => db_gem.name
     lambda {
       gem.delete
     }.should change(ManagedGem, :count).by(-1)
     lambda {
       ManagedGem.find(db_gem.id)
     }.should raise_error(ActiveRecord::RecordNotFound)
   end

   it "should trigger update" do
      db_gem   = ManagedGem.create :name => 'dsl-trigger-test', :gem_source_id => 1
      event = Event.create :managed_gem => db_gem,
                           :process => "integration_test_handler1",
                           :version_qualifier => '>',
                           :gem_version => 1.2

      source = Polisher::GemSource.new :uri => "http://gemcutter.org"
      gem = Polisher::ManagedGem.new :id => db_gem.id, :name => db_gem.name, :source => source
      gem.released 1.6
      $integration_test_handler_flags.include?(1).should == true
   end
end

describe "Polisher::DSL::GemSource" do
   it "should be instantiatable from xml" do
     xml = "<source><id>10</id><name>foo</name><uri>http://host</uri></source>"
     source = Polisher::GemSource.from_xml xml
     source.id.should   == 10
     source.name.should == "foo"
     source.uri.should  == "http://host"
   end
end

describe "Polisher::DSL::Project" do
   it "should be instantiatable from xml" do
     xml = "<project><id>10</id><name>foo</name><sources><source><id>s1</id><uri>uuu1</uri></source><source><id>2</id><uri>uuu2</uri></source></sources></project>"
     project = Polisher::Project.from_xml xml
     project.id.should   == 10
     project.name.should == "foo"
     project.sources.size.should == 2
     project.sources[0].should == "uuu1"
     project.sources[1].should == "uuu2"
   end

   it "should allow project deletion" do
     db_project = Project.create! :name => "project-event-deletion-test"
     project = Polisher::Project.new :id => db_project.id, :name => db_project.name
     lambda {
       project.delete
     }.should change(Project, :count).by(-1)
     lambda {
       Project.find(db_project.id)
     }.should raise_error(ActiveRecord::RecordNotFound)
   end

   it "should allow event creations" do
     db_project = Project.create! :name => "project-event-creation-test"
     project    = Polisher::Project.new :id => db_project.id, :name => db_project.name
     lambda {
       project.on_version "<", "3.9", "do something", "options"
     }.should change(Event, :count).by(1)
     Event.find(:first, :conditions => [ 'project_id = ? AND version_qualifier = ? AND gem_version = ? AND process = ? AND process_options = ?',
                                          project.id, "<", "3.9", "do something", "options" ]).
                                          should_not be_nil
   end

   it "should trigger release" do
      db_project   = Project.create :name => 'dsl-trigger-test'
      event = Event.create :project => db_project,
                           :process => "integration_test_handler2",
                           :version_qualifier => '<',
                           :gem_version => 1.0

      project = Polisher::Project.new :id => db_project.id, :name => db_project.name
      project.released 0.9
      $integration_test_handler_flags.include?(2).should == true
   end
end


describe "Polisher::DSL" do
  it "should return all gems" do
      gem1   = ManagedGem.create! :name => 'dsl-gems-test1', :gem_source_id => 1
      gem2   = ManagedGem.create! :name => 'dsl-gems-test2', :gem_source_id => 1
      test_gems = gems
      ManagedGem.find(:all).each { |gem|
        test_gems.find { |g| g.name == gem.name && g.source.name == gem.source.name }.should_not be_nil
      }
  end

  it "should find or create gem" do
    test_gem = nil
    lambda {
      test_gem = gem :name => "dsl-gem-test", :source => "gemcutter"
    }.should change(ManagedGem, :count).by(1)
    db_gem = ManagedGem.find(:first, :conditions => ['name = ? AND gem_source_id = ?', 'dsl-gem-test', 1])
    test_gem.id.should == db_gem.id

    lambda {
      test_gem = gem :name => "dsl-gem-test", :gem_source_id => 1
    }.should_not change(ManagedGem, :count)
    test_gem.id.should == db_gem.id

    test_gem = gem :name => "dsl-gem-test"
    test_gem.id.should == db_gem.id
  end

  it "should return all sources" do
      source1   = GemSource.create! :name => 'dsl-sources-test1', :uri => "http://test1.host"
      source2   = GemSource.create! :name => 'dsl-sources-test2', :uri => "http://test2.host"
      test_sources = sources
      GemSource.find(:all).each { |source|
        test_sources.find { |s| s.name == source.name && s.uri == source.uri }.should_not be_nil
      }
      test_sources.find { |s| s.name == "dsl-sources-test1" && s.uri == "http://test1.host" }.should_not be_nil
      test_sources.find { |s| s.name == "dsl-sources-test2" && s.uri == "http://test2.host" }.should_not be_nil
  end

  it "should find or create source" do
    test_source = nil
    lambda {
      test_source = source :name => "dsl-source-test", :uri => "http://source.test"
    }.should change(GemSource, :count).by(1)
    db_source = GemSource.find(:first, :conditions => ['name = ? AND uri = ?', 'dsl-source-test', 'http://source.test'])
    test_source.id.should == db_source.id

    lambda {
      test_source = source :name => "dsl-source-test", :uri => "http://source.test"
    }.should_not change(GemSource, :count)
    test_source.id.should == db_source.id

    test_source = source :name => "dsl-source-test"
    test_source.id.should == db_source.id
  end

  it "should return all projects" do
      proj1   = Project.create! :name => 'dsl-projects-test1'
      proj2   = Project.create! :name => 'dsl-projects-test2'
      test_projects = projects
      Project.find(:all).each { |proj|
        test_projects.find { |p| p.name == proj1.name }.should_not be_nil
      }
  end

  it "should find or create project" do
    test_project = nil
    lambda {
      test_project = project :name => "dsl-project-test"
    }.should change(Project, :count).by(1)
    db_project = Project.find(:first, :conditions => ['name = ?', 'dsl-project-test'])
    test_project.id.should == db_project.id

    lambda {
      test_project = project :name => "dsl-project-test"
    }.should_not change(Project, :count)
    test_project.id.should == db_project.id
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
