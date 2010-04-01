# ruby gem polisher spec
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

describe "Polisher" do

  it "should redirect / to /gems" do
    get '/'
    last_response.should_not be_ok
    follow_redirect!
    last_request.url.should == "http://example.org/gems"
    last_response.should be_ok
  end

  it "should respond to /gems" do
    get '/gems'
    last_response.should be_ok
  end

  it "should get gems in xml format" do
    post '/gems/create', :name => 'gem-xml-test1', :gem_source_id => 1
    post '/gems/create', :name => 'gem-xml-test2', :gem_source_id => 1
    get '/gems.xml'
    last_response.should be_ok

    expect = "<gems>"
    ManagedGem.find(:all).each { |g| expect += "<gem><id>#{g.id}</id><name>#{g.name}</name><gem_source_id>#{g.gem_source_id}</gem_source_id></gem>" }
    expect += "</gems>"
    last_response.body.gsub(/\s*/, '').should == expect.gsub(/\s*/, '') # ignore whitespace differences
  end

  it "should allow gem creations" do
    lambda do
      post '/gems/create', :name => 'create-gem-test', :gem_source_id => 1
    end.should change(ManagedGem, :count).by(1)
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/gems"
  end

  it "should allow gem deletions" do
    post '/gems/create', :name => 'delete-gem-test', :gem_source_id => 1
    gem_id = ManagedGem.find(:first, :conditions => ['name = ?', 'delete-gem-test']).id
    lambda do
      delete "/gems/destroy/#{gem_id}"
    end.should change(ManagedGem, :count).by(-1)
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/gems"
  end

  # run simulate gemcutter api firing process
  it "should successfully post-process a released gem" do
      gem   = ManagedGem.create :name => 'foobar', :gem_source_id => 1

      event = Event.create :managed_gem => gem, 
                           :process => "integration_test_handler1",
                           :version_qualifier => '>',
                           :gem_version => 1.2

      event = Event.create :managed_gem => gem, 
                           :process => "integration_test_handler2",
                           :version_qualifier => '<',
                           :gem_version => 1.1

      post '/gems/released', :name => 'foobar',
                            :version => '1.3', 
                            :gem_uri => 'http://gemcutter.org/gems/foobar-1.3.gem'

      $integration_test_handler_flags.include?(1).should == true
      $integration_test_handler_flags.include?(2).should == false
  end

  it "should respond to /gem_sources" do
    get '/gem_sources'
    last_response.should be_ok
  end

  it "should allow gem source creations" do
    lambda do
      post '/gem_sources/create', :name => 'create-gem-source-test', :uri => 'http://example1.org'
    end.should change(GemSource, :count).by(1)
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/gem_sources"
  end

  it "should get gem sources in xml format" do
    post '/gem_sources/create', :name => 'gem-source-xml-test1', :uri => 'http://foo.host'
    post '/gem_sources/create', :name => 'gem-source-xml-test2', :uri => 'http://bar.host'
    get '/gem_sources.xml'
    last_response.should be_ok

    expect = "<gem_sources>"
    GemSource.find(:all).each { |s| expect += "<source><id>#{s.id}</id><name>#{s.name}</name><uri>#{s.uri}</uri></source>" }
    expect += "</gem_sources>"
    last_response.body.gsub(/\s*/, '').should == expect.gsub(/\s*/, '') # ignore whitespace differences
  end


  it "should allow gem source deletions" do
    post '/gem_sources/create', :name => 'delete-gem-source-test', :uri => 'http://example2.org'
    gem_source_id = GemSource.find(:first, :conditions => ['name = ?', 'delete-gem-source-test']).id
    lambda do
      delete "/gem_sources/destroy/#{gem_source_id}"
    end.should change(GemSource, :count).by(-1)
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/gem_sources"
  end

  it "should respond to /projects" do
    get '/projects'
    last_response.should be_ok
  end

  it "should allow project creations" do
    lambda do
      post '/projects/create', :name => 'create-project-test'
    end.should change(Project, :count).by(1)
    project = Project.find(:first, :conditions => [ 'name = ?', 'create-project-test'])
    project.should_not be_nil

    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/projects"
  end

  it "should get projects in xml format" do
    post '/projects/create', :name => 'project-xml-test1', :sources => [{:uri => 'ccpts1'}]
    post '/projects/create', :name => 'project-xml-test2'
    get '/projects.xml'
    last_response.should be_ok

    expect = "<projects>"
    Project.find(:all).each { |p|
      expect += "<project><id>#{p.id}</id><name>#{p.name}</name><sources>"
      p.sources.each { |s|
        expect += "<source><id>#{s.id.to_s}</id><uri>#{s.uri}</uri></source>"
      }
      expect += "</sources></project>"
    }
    expect += "</projects>"
    last_response.body.gsub(/\s*/, '').should == expect.gsub(/\s*/, '') # ignore whitespace differences
  end


  it "should allow project deletions" do
    post '/projects/create', :name => 'delete-project-test'
    project_id = Project.find(:first, :conditions => ['name = ?', 'delete-project-test']).id
    lambda do
      delete "/projects/destroy/#{project_id}"
    end.should change(Project, :count).by(-1)
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/projects"
  end

  # test triggering release event
  it "should successfully post-process a released project" do
      project   = Project.create :name => 'myproj'

      event = Event.create :project => project,
                           :process => "integration_test_handler3",
                           :version_qualifier => '=',
                           :gem_version => "5.6"

      event = Event.create :project => project,
                           :process => "integration_test_handler4",
                           :version_qualifier => '>',
                           :gem_version => "7.9"

      post '/projects/released', :name => 'myproj',
                                 :version => "5.6"

      $integration_test_handler_flags.include?(3).should == true
      $integration_test_handler_flags.include?(4).should == false
  end

  # test triggering release event
  it "should successfully post-process a released project w/ request params" do
      project   = Project.create :name => 'post-process-project2'

      event = Event.create :project => project,
                           :process => "integration_test_handler5",
                           :version_qualifier => '=',
                           :gem_version => "5.0"

      post '/projects/released', :name => 'post-process-project2',
                                 :version => "5.0",
                                 :xver  => "5.0.2-122"

      $integration_test_handler_flags.include?("xver5.0.2-122").should == true
  end

  it "should allow project source creations" do
    project = Project.create! :name => "create-project_source-test1"
    lambda do
      post '/project_sources/create', :uri => 'create-project_source-test', :project_id => project.id
    end.should change(ProjectSource, :count).by(1)
    project = ProjectSource.find(:first, :conditions => [ 'uri = ? AND project_id = ?', 'create-project_source-test', project.id])
    project.should_not be_nil

    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/projects"
  end

  it "should allow project source deletions" do
    project = Project.create! :name => "create-project_source-test2"
    post '/project_sources/create', :uri => 'create-project_source-test2', :project_id => project.id
    ps = ProjectSource.find(:first, :conditions => [ 'uri = ? AND project_id = ?', 'create-project_source-test2', project.id])
    lambda do
      delete "/project_sources/destroy/#{ps.id}"
    end.should change(ProjectSource, :count).by(-1)
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/projects"
  end

  it "should allow gem event creations" do
    gem = ManagedGem.create! :name => "create-event-test-gem", :gem_source_id => 1
    lambda do
      post '/events/create', :managed_gem_id => gem.id, 
                             :process => 'fooproc', 
                             :gem_version => '1.0',
                             :version_qualifier => ">",
                             :process_options => 'opts'
    end.should change(Event, :count).by(1)
    Event.find(:first,
               :conditions => ['managed_gem_id = ? AND process = ? AND gem_version = ? ' +
                               'AND version_qualifier = ? AND process_options = ?',
                               gem.id, 'fooproc', '1.0', '>', 'opts']).should_not be_nil
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/gems"
  end

  it "should allow project event creations" do
    project = Project.create! :name => "create-event-test-project"
    lambda do
      post '/events/create', :project_id => project.id,
                             :process => 'fooproc',
                             :gem_version => '1.0',
                             :version_qualifier => ">",
                             :process_options => 'opts'
    end.should change(Event, :count).by(1)
    Event.find(:first,
               :conditions => ['project_id = ? AND process = ? AND gem_version = ? ' +
                               'AND version_qualifier = ? AND process_options = ?',
                               project.id, 'fooproc', '1.0', '>', 'opts']).should_not be_nil
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/projects"
  end

  it "should allow event deletions" do
    gem = ManagedGem.create :name => "delete-event-test-gem", :gem_source_id => 1
    post '/events/create', :managed_gem_id => gem.id, :process => 'fooproc'
    lambda do
      delete '/events/destroy/1'
    end.should change(Event, :count).by(-1)
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/gems"
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

def integration_test_handler3(entity, process_options = [], optional_params = {})
  $integration_test_handler_flags << 3
end

def integration_test_handler4(entity, process_options = [], optional_params = {})
  $integration_test_handler_flags << 4
end

def integration_test_handler5(entity, process_options = [], optional_params = {})
  optional_params.each { |k,v|
    $integration_test_handler_flags << "#{k}#{v}"
  }
end
