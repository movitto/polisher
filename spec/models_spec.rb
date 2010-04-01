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


describe "Polisher::GemSource" do
   it "should not be valid if name or uri is missing" do
      src = GemSource.new :name => 'foo', :uri => 'bar'
      src.valid?.should be(true)

      src.name = nil
      src.valid?.should be(false)
      src.name = 'foo'

      src.uri = nil
      src.valid?.should be(false)
   end

   it "should clean uri properly" do
      src = GemSource.new :uri => 'http://example.com/'
      src.clean_uri!
      src.uri.should == 'http://example.com'
   end

end


describe "Polisher::ManagedGem" do
  it "should not be valid if name or gem source is missing" do
      gem = ManagedGem.new :name => 'foo', :gem_source_id => 1
      gem.valid?.should be(true)

      gem.name = nil
      gem.valid?.should be(false)
      gem.name = 'foo'

      gem.gem_source_id = nil
      gem.valid?.should be(false)
  end

  it "should not be valid if name is not unique within gem source scope" do
     gem1 = ManagedGem.create :name => 'foo', :gem_source_id => 1
     gem2 = ManagedGem.new :name => 'foo', :gem_source_id => 1
     gem2.valid?.should be(false)
  end

  it "should generate correct gem source uri from gem uri" do
     ManagedGem.uri_to_source_uri('http://rubygems.org/downloads/polisher-0.3.gem').
         should == 'http://rubygems.org'
  end

  it "should successfully subscribe/unsubscribe to updates" do
     gem = ManagedGem.new :name => "polisher", :gem_source_id => 1
     gem.subscribe :callback_url => "http://projects.morsi.org/polisher/demo/gems/released/1"
     gem.subscribed?.should == true
     gem.unsubscribe :callback_url => "http://projects.morsi.org/polisher/demo/gems/released/1"
     gem.subscribed?.should == false
  end

  it "should successfully get remote gem info" do
     gem = ManagedGem.new :name => "polisher", :gem_source_id => 1
     info = gem.get_info
     info["name"].should == "polisher"
  end

  it "should successfully download gem" do
     FileUtils.rm_rf(ARTIFACTS_DIR) if File.directory? ARTIFACTS_DIR
     FileUtils.mkdir_p(ARTIFACTS_DIR)

     gem = ManagedGem.new :name => "polisher", :gem_source_id => 1
     path = gem.download_to(:dir => ARTIFACTS_DIR, :version => 0.3)
     File.size?(ARTIFACTS_DIR + '/polisher-0.3.gem').should_not be_nil
     FileUtils.rm(ARTIFACTS_DIR + '/polisher-0.3.gem')
     path.should == ARTIFACTS_DIR + '/polisher-0.3.gem'


     gem.download_to(:path => ARTIFACTS_DIR + '/my.gem', :version => 0.3)
     File.size?(ARTIFACTS_DIR + '/my.gem').should_not be_nil

     gem.download_to(:dir => ARTIFACTS_DIR)
     File.size?(ARTIFACTS_DIR + '/polisher-0.3.gem').should_not be_nil
  end

end

describe "Polisher::Project" do
  it "should not be valid if name is missing" do
      project = Project.new :name => 'foo'
      project.valid?.should be(true)

      project.name = nil
      project.valid?.should be(false)
  end


  it "should not be valid if duplicate name exists" do
      Project.create! :name => 'dup-project-name-test'
      project = Project.new :name => 'dup-project-name-test'
      project.valid?.should be(false)
  end
end

describe "Polisher::ProjectSource" do
  it "should not be valid if project_id or uri is missing" do
      project = Project.create :name => 'project-source-test1'
      source = ProjectSource.new :uri => 'uri', :project_id => project.id
      source.valid?.should be(true)

      source.uri = nil
      source.valid?.should be(false)
      source.uri = 'foo'

      source.project_id = nil
      source.valid?.should be(false)
  end

  it "should not be valid if uri is not unique in project scope" do
      project = Project.create! :name => 'project-uri-test'
      source1 = ProjectSource.create! :uri => 'uri', :project_id => project.id
      source2 = ProjectSource.new :uri => 'uri', :project_id => project.id
      source2.valid?.should be(false)
  end

  it "should be downloadable" do
     FileUtils.rm_rf(ARTIFACTS_DIR) if File.directory? ARTIFACTS_DIR
     FileUtils.mkdir_p(ARTIFACTS_DIR)
     
     project = Project.create!(:name => 'project-source-download-to-test')
     source = ProjectSource.create!(
        #:uri => 'ftp://ftp.ruby-lang.org/pub/ruby/1.8/ruby-1.8.6-p388.tar.bz2',
        :uri => 'http://mo.morsi.org/files/jruby/joni.spec',
        :project => project)
     path = source.download_to(:dir => ARTIFACTS_DIR)
     File.size?(ARTIFACTS_DIR + '/joni.spec').should_not be_nil
     FileUtils.rm(ARTIFACTS_DIR + '/joni.spec')
     path.should == ARTIFACTS_DIR + '/joni.spec'

     source.download_to(:path => ARTIFACTS_DIR + '/joni.spec')
     File.size?(ARTIFACTS_DIR + '/joni.spec').should_not be_nil
  end
end

describe "Polisher::Event" do

   it "should not be valid if process is missing" do
      gem = ManagedGem.create :name => 'valid-event-test-gem1', :gem_source_id => 1
      event = Event.new :managed_gem_id => gem.id, :process => 'create_repo'
      event.valid?.should be(true)

      event.process = nil
      event.valid?.should be(false)
   end

   it "should not be valid if both managed_gem and project are missing" do
      gem = ManagedGem.create :name => 'valid-event-test-gem1b', :gem_source_id => 1
      project = Project.create :name => 'valid-event-test-project1'
      event = Event.new :process => 'create_repo'
      event.valid?.should be(false)
      event.managed_gem = gem
      event.valid?.should be(true)
      event.managed_gem = nil
      event.project = project
      event.valid?.should be(true)
   end

   it "should not be valid with invalid version qualifier" do
      gem = ManagedGem.create :name => 'valid-event-test-gem2', :gem_source_id => 1

      event = Event.new :managed_gem_id => gem.id, :process => 'create_repo', :version_qualifier => ">", :gem_version => 5
      event.valid?.should be(true)

      event.version_qualifier = '=='
      event.valid?.should be(false)
   end

   it "should not be valid if version/qualifier are not both present or nil" do
      gem = ManagedGem.create :name => 'valid-event-test-gem3', :gem_source_id => 1
 
      event = Event.new :managed_gem_id => gem.id, :process => 'create_repo', :version_qualifier => ">"
      event.valid?.should be(false)
 
      event = Event.new :managed_gem_id => gem.id, :process => 'create_repo', :gem_version => 5
      event.valid?.should be(false)

      event = Event.new :managed_gem_id => gem.id, :process => 'create_repo', :gem_version => 5, :version_qualifier => '<='
      event.valid?.should be(true)
   end

   it "should correctly resolve version qualifiers" do
      event = Event.new :version_qualifier => nil
      event.applies_to_version?('1.1').should be(true)

      event = Event.new :version_qualifier => "=", :gem_version => "5.3"
      event.applies_to_version?('1.2').should be(false)
      event.applies_to_version?('5.3').should be(true)
      event.applies_to_version?('7.9').should be(false)

      event = Event.new :version_qualifier => ">", :gem_version => "1.9"
      event.applies_to_version?('1.8').should be(false)
      event.applies_to_version?('1.9').should be(false)
      event.applies_to_version?('2.0').should be(true)

      event = Event.new :version_qualifier => "<", :gem_version => "0.6"
      event.applies_to_version?('0.5').should be(true)
      event.applies_to_version?('0.6').should be(false)
      event.applies_to_version?('0.7').should be(false)

      event = Event.new :version_qualifier => ">=", :gem_version => "1.9"
      event.applies_to_version?('1.8').should be(false)
      event.applies_to_version?('1.9').should be(true)
      event.applies_to_version?('2.0').should be(true)

      event = Event.new :version_qualifier => "<=", :gem_version => "0.6"
      event.applies_to_version?('0.5').should be(true)
      event.applies_to_version?('0.6').should be(true)
      event.applies_to_version?('0.7').should be(false)
   end

   it "should successfully run event process" do
      gem = ManagedGem.new :name => "foobar"
      event = Event.new :managed_gem => gem, :process => "test_event_run_method", :process_options => "a;b;c"
      event.run

      $test_event_run_hash[:gem].should_not be_nil
      $test_event_run_hash[:first].should_not be_nil
      $test_event_run_hash[:second].should_not be_nil
      $test_event_run_hash[:third].should_not be_nil

      $test_event_run_hash[:gem].name.should == "foobar"
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
end

# prolly should fixure out a better way todo this
$test_event_run_hash = {}

# helper method, invoked in Event::run spec
def test_event_run_method(entity, process_options = [nil, nil, nil], optional_params = {})
  $test_event_run_hash[:gem]     = entity if entity.class == ManagedGem
  $test_event_run_hash[:project] = entity if entity.class == Project
  $test_event_run_hash[:first]  = process_options[0]
  $test_event_run_hash[:second] = process_options[1]
  $test_event_run_hash[:third]  = process_options[2]
  $test_event_run_hash[:key1]   = optional_params[:key1]
  $test_event_run_hash[:some]   = optional_params[:some]
  $test_event_run_hash[:answer] = optional_params[:answer]
end
