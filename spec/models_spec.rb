# ruby gem polisher models spec
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

require File.dirname(__FILE__) + '/spec_helper'

describe "Polisher::Project" do
  it "should not be valid if name is missing" do
      project = Project.new :name => 'foo'
      project.should be_valid

      project.name = nil
      project.should_not be_valid
  end


  it "should not be valid if duplicate name exists" do
      Project.create! :name => 'dup-project-name-test'
      project = Project.new :name => 'dup-project-name-test'
      project.should_not be_valid
  end
end

describe "Polisher::Source" do
  it "should not be valid if name, source_type, or uri is missing or invalid" do
      source = Source.new :uri => 'uri', :name => "foo", :source_type => "gem"
      source.should be_valid

      source.uri = nil
      source.should_not be_valid
      source.uri = 'uri'

      source.source_type = nil
      source.should_not be_valid
      source.source_type = 'bar'
      source.should_not be_valid
      source.source_type = 'file'

      source.name = nil
      source.should_not be_valid
  end

  it "should not be valid if name or uri is not unique in scope" do
      source1 = Source.create! :uri => 'uri', :name => "foo", :source_type => "gem"
      source2 = Source.new :uri => 'uri', :name => "bar", :source_type => "archive"
      source2.should_not be_valid

      source3 = Source.new :uri => 'zaz', :name => "foo", :source_type => "archive"
      source3.should_not be_valid
  end

  it "should be downloadable" do
     FileUtils.rm_rf(ARTIFACTS_DIR) if File.directory? ARTIFACTS_DIR
     FileUtils.mkdir_p(ARTIFACTS_DIR)
     
     source = Source.new(
        :uri => 'http://mo.morsi.org/files/jruby/joni.spec',
        :name => "joni-spec", :source_type => "file")
     path = source.download_to(:dir => ARTIFACTS_DIR)
     File.size?(ARTIFACTS_DIR + '/joni.spec').should_not be_nil
     FileUtils.rm(ARTIFACTS_DIR + '/joni.spec')
     path.should == ARTIFACTS_DIR + '/joni.spec'

     source.download_to(:path => ARTIFACTS_DIR + '/joni.spec')
     File.size?(ARTIFACTS_DIR + '/joni.spec').should_not be_nil
  end

  it "should permit a parameterized download" do
     FileUtils.rm_rf(ARTIFACTS_DIR) if File.directory? ARTIFACTS_DIR
     FileUtils.mkdir_p(ARTIFACTS_DIR)

     source = Source.new(
        :uri => 'http://mo.morsi.org/files/%{group}/%{name}.spec',
        :name => "joni-spec", :source_type => 'file')
     path = source.download_to(:dir => ARTIFACTS_DIR, :variables => {:group => "jruby", :name => "joni"})
     File.size?(ARTIFACTS_DIR + '/joni.spec').should_not be_nil
     FileUtils.rm(ARTIFACTS_DIR + '/joni.spec')
     path.should == ARTIFACTS_DIR + '/joni.spec'

     source.download_to(:path => ARTIFACTS_DIR + '/joni.spec')
     File.size?(ARTIFACTS_DIR + '/joni.spec').should_not be_nil
  end

  it "should raise an exception if download source uri or destination path is invalid" do
     FileUtils.rm_rf(ARTIFACTS_DIR) if File.directory? ARTIFACTS_DIR
     FileUtils.mkdir_p(ARTIFACTS_DIR)

     source = Source.new(
        :uri => 'http://invalid.uri',
        :name => 'invalid-source1', :source_type => 'file')
     lambda {
       path = source.download_to(:dir => ARTIFACTS_DIR)
     }.should raise_error(RuntimeError)

     source = Source.new(
        :uri => 'http://mo.morsi.org/files/jruby/joni.spec',
        :name => 'invalid-source2', :source_type => 'file')
     lambda {
       path = source.download_to(:dir => '/')
     }.should raise_error(RuntimeError)

     lambda {
       path = source.download_to(:dir => '/nonexistantfoobar')
     }.should raise_error(RuntimeError)
  end
end

describe "Polisher::Event" do

   it "should not be valid if process is missing" do
      project = Project.create! :name => 'valid-event-test-project0'
      event = Event.new :project_id => project.id, :process => 'create_repo'
      event.should be_valid

      event.process = nil
      event.should_not be_valid
   end

   it "should not be valid if project is missing" do
      project = Project.create! :name => 'valid-event-test-project1'
      event = Event.new :process => 'create_repo'
      event.should_not be_valid
      event.project = project
      event.should be_valid
   end

   it "should not be valid with invalid version qualifier" do
      project = Project.create! :name => 'valid-event-test-project2'

      event = Event.new :project_id => project.id, :process => 'create_repo', :version_qualifier => ">", :version => 5
      event.should be_valid

      event.version_qualifier = '=='
      event.should_not be_valid
   end

   it "should not be valid if version/qualifier are not both present or nil" do
      project = Project.create! :name => 'valid-event-test-project3'
 
      event = Event.new :project_id => project.id, :process => 'create_repo', :version_qualifier => ">"
      event.should_not be_valid
 
      event = Event.new :project_id => project.id, :process => 'create_repo', :version => 5
      event.should_not be_valid

      event = Event.new :project_id => project.id, :process => 'create_repo', :version => 5, :version_qualifier => '<='
      event.should be_valid
   end

   it "should correctly resolve version qualifiers" do
      event = Event.new :version_qualifier => nil, :version => "5"
      event.applies_to_version?('1.1').should be(true)
      event.applies_to_version?('1.5.3').should be(true)

      event = Event.new :version_qualifier => "=", :version => "5.3"
      event.applies_to_version?('1.2').should be(false)
      event.applies_to_version?('5.3').should be(true)
      event.applies_to_version?('5.3.0').should be(false)
      event.applies_to_version?('5.3.1').should be(false)
      event.applies_to_version?('7.9').should be(false)

      event = Event.new :version_qualifier => ">", :version => "1.9.2"
      event.applies_to_version?('1.8.1').should be(false)
      event.applies_to_version?('1.9.1').should be(false)
      event.applies_to_version?('1.9.3').should be(true)
      event.applies_to_version?('2.0').should be(true)

      event = Event.new :version_qualifier => "<", :version => "0.6"
      event.applies_to_version?('0.5').should be(true)
      event.applies_to_version?('0.6').should be(false)
      event.applies_to_version?('0.7').should be(false)

      event = Event.new :version_qualifier => ">=", :version => "1.9"
      event.applies_to_version?('1.8').should be(false)
      event.applies_to_version?('1.9').should be(true)
      event.applies_to_version?('2.0').should be(true)

      event = Event.new :version_qualifier => "<=", :version => "0.6.4"
      event.applies_to_version?('0.5.2').should be(true)
      event.applies_to_version?('0.6.1').should be(true)
      event.applies_to_version?('0.6.6').should be(false)
      event.applies_to_version?('0.7.4').should be(false)
   end

   it "should raise error if trying to compare invalid versions" do
      event = Event.new
      lambda {
        event.applies_to_version?('0.5.2')
      }.should raise_error(ArgumentError)

      event.version = '0.7'
      lambda {
        event.applies_to_version?(111)
      }.should raise_error(ArgumentError)
   end

   it "should successfully run event process" do
      project = Project.new :name => "foobar"
      event = Event.new :project => project, :process => "test_event_run_method", :process_options => "a;b;c"
      event.run

      $test_event_run_hash[:project].should_not be_nil
      $test_event_run_hash[:first].should_not be_nil
      $test_event_run_hash[:second].should_not be_nil
      $test_event_run_hash[:third].should_not be_nil

      $test_event_run_hash[:project].name.should == "foobar"
      $test_event_run_hash[:first].should == "a"
      $test_event_run_hash[:second].should == "b"
      $test_event_run_hash[:third].should == "c"
   end

   it "should successfully run event process w/ optional params" do
      project = Project.new :name => "fumanchu"
      event = Event.new :project => project, :process => "test_event_run_method", :process_options => "a;b;c"
      event.run(:key1 => "val1", :some => "thing", :answer => 42)

      $test_event_run_hash[:key1].should_not be_nil
      $test_event_run_hash[:some].should_not be_nil
      $test_event_run_hash[:answer].should_not be_nil

      $test_event_run_hash[:project].name.should == "fumanchu"
      $test_event_run_hash[:key1].should == "val1"
      $test_event_run_hash[:some].should == "thing"
      $test_event_run_hash[:answer].should == 42
   end

   it "should raise an exception if running event process that doesn't correspond to a method" do
      project = Project.new :name => "foobar"
      event = Event.new :project => project, :process => "non_existant_method"
      lambda {
        event.run
      }.should raise_error(ArgumentError)
   end

   it "should raise an exception if event process being run does" do
      project = Project.new :name => "foobar"
      event = Event.new :project => project, :process => "error_generating_method"
      lambda {
        event.run
      }.should raise_error(RuntimeError)
   end
end

# prolly should fixure out a better way todo this
$test_event_run_hash = {}

# helper method, invoked in Event::run spec
def test_event_run_method(entity, process_options = [nil, nil, nil], optional_params = {})
  $test_event_run_hash[:project] = entity if entity.class == Project
  $test_event_run_hash[:first]  = process_options[0]
  $test_event_run_hash[:second] = process_options[1]
  $test_event_run_hash[:third]  = process_options[2]
  $test_event_run_hash[:key1]   = optional_params[:key1]
  $test_event_run_hash[:some]   = optional_params[:some]
  $test_event_run_hash[:answer] = optional_params[:answer]
end

def error_generating_method(entity, process_options = [nil, nil, nil], optional_params = {})
  raise RuntimeError
end
