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

require 'libxml'

describe "Polisher" do

  it "should redirect / to /projects" do
    get '/'
    last_response.should_not be_ok
    follow_redirect!
    last_request.url.should == "http://example.org/projects"
    last_response.should be_ok
  end

  it "should return projects in html format" do
    get '/projects.html'
    last_response.should be_ok
  end

  it "should return projects in xml format" do
    post '/projects/create', :name => 'project-xml-test1'
    post '/projects/create', :name => 'project-xml-test2'
    get '/projects'
    last_response.should be_ok

    expect = "<projects>"
    Project.find(:all).each { |p|
      expect += "<project><id>#{p.id}</id><name>#{p.name}</name><versions>"
      p.versions.each { |v|
        expect += "<version><id>#{v}</id><sources>"
        p.project_source_versions_for_version(v).each { |ps|
          expect += "<source><uri>#{ps.source.uri}</uri><version>#{ps.source_version}</version></source>"
        }
        expect += "</sources><events>"
        p.events_for_version(v).each { |e|
          expect += ("<event><process>#{e.process}</process>" +
                     "<process_options>#{e.process_options}</process_options>" +
                     "<version_qualifier>#{e.version_qualifier}</version_qualifier>" +
                     "<version>#{e.version}</version></event>")
        }
        expect += "</events></version>"
      }
      expect += "</versions></project>"
    }
    expect += "</projects>"
    last_response.body.gsub(/\s*/, '').should == expect.gsub(/\s*/, '') # ignore whitespace differences
  end

  it "should allow project creations" do
    lambda do
      post '/projects/create', :name => 'create-project-test'
    end.should change(Project, :count).by(1)
    project = Project.find(:first, :conditions => [ 'name = ?', 'create-project-test'])
    project.should_not be_nil

    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "true"
  end

  it "should return an error if project name is not specified on creation" do
    lambda do
      post '/projects/create'
    end.should_not change(Project, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"
  end

  it "should return an error if a duplicate project is created" do
    lambda do
      post '/projects/create', :name => 'create-project-test2'
    end.should change(Project, :count).by(1)

    lambda do
      post '/projects/create', :name => 'create-project-test2'
    end.should_not change(Project, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"
  end

  it "should allow project deletions" do
    post '/projects/create', :name => 'delete-project-test'
    project_id = Project.find(:first, :conditions => ['name = ?', 'delete-project-test']).id
    lambda do
      delete "/projects/destroy/#{project_id}"
    end.should change(Project, :count).by(-1)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "true"
  end

  it "should return an error if project id to delete is invalid" do
    lambda do
      delete "/projects/destroy/abc"
    end.should_not change(Project, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"
  end

  # test triggering release event
  it "should successfully post-process a released project" do
    project   = Project.create :name => 'myproj'

    event = Event.create :project => project,
                         :process => "integration_test_handler3",
                         :version_qualifier => '=',
                         :version => "5.6"

    event = Event.create :project => project,
                         :process => "integration_test_handler4",
                         :version_qualifier => '>',
                         :version => "7.9"

    post '/projects/released', :name => 'myproj',
                               :version => "5.6"

    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "true"

    $integration_test_handler_flags.include?(3).should be_true
    $integration_test_handler_flags.include?(4).should be_false
  end

  it "should return an error if there is a problem in the project release process" do
      project   = Project.create :name => 'foobar42'

      event = Event.create :project => project,
                           :process => "failed_event_handler",
                           :version_qualifier => '=',
                           :version => 1.0


      # need to specify name and version
      post '/projects/released', :name => 'foobar42'
      last_response.should be_ok
      LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"

      post '/projects/released', :version => '1.0'
      last_response.should be_ok
      LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"

      # event handler should throw exception, which the app should return
      post '/projects/released', :name => 'foobar42',
                            :version => '1.0'
      last_response.should be_ok
      LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"
      LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "errors" }.content.strip.should =~ /.*MYERROR.*/
      LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "message" }.content.strip.should =~ /.*MYERROR.*/
  end

  # test triggering release event
  it "should successfully post-process a released project w/ request params" do
      project   = Project.create :name => 'post-process-project2'

      event = Event.create :project => project,
                           :process => "integration_test_handler5",
                           :version_qualifier => '=',
                           :version => "5.0"

      post '/projects/released', :name => 'post-process-project2',
                                 :version => "5.0",
                                 :xver  => "5.0.2-122"

      $integration_test_handler_flags.include?("xver5.0.2-122").should be_true
  end

  it "should return sources in html format" do
    get '/sources.html'
    last_response.should be_ok
  end

  it "should return sources in xml format" do
    post '/sources/create', :name => 'sources-xml-test1', :uri => 'http://foo.uri', :source_type => 'file'
    post '/sources/create', :name => 'sources-xml-test2', :uri => 'http://bar.uri', :source_type => 'file'
    get '/sources'
    last_response.should be_ok

    expect = "<sources>"
    Source.find(:all).each { |s|
      expect += "<source><id>#{s.id}</id><name>#{s.name}</name><source_type>#{s.source_type}</source_type><uri>#{s.uri}</uri><versions>"
      s.versions.each { |v|
        expect += "<version><id>#{v}</id><projects>"
        s.project_source_versions_for_version(version).each { |ps|
          expect += "<project><name>#{ps.project.name}</name><version>#{ps.project_version}</version></project>"
        }
        expect += "</projects></version>"
      }
      expect += "</versions></source>"
    }
    expect += "</sources>"
    last_response.body.gsub(/\s*/, '').should == expect.gsub(/\s*/, '') # ignore whitespace differences
  end

  it "should allow source creations" do
    lambda do
      post '/sources/create', :name => 'create-source-test', :uri => 'http://create-source-test.uri', :source_type => 'gem'
    end.should change(Source, :count).by(1)
    project = Source.find(:first, :conditions => [ 'name = ? AND uri = ? AND source_type = ?', 'create-source-test', 'http://create-source-test.uri', 'gem'])
    project.should_not be_nil

    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "true"
  end

  it "should return an error if source name, uri, or source_type is not specified on creation" do
    lambda do
      post '/sources/create'
    end.should_not change(Source, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"

    lambda do
      post '/sources/create', :name => 'invalid-source-test1'
    end.should_not change(Source, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"

    lambda do
      post '/sources/create', :name => 'invalid-source-test2', :uri => 'http://invalid-source2.uri'
    end.should_not change(Source, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"

    lambda do
      post '/sources/create', :source_type => 'gem'
    end.should_not change(Source, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"
  end

  it "should return an error if a duplicate project or other error occurs on creation" do
    lambda do
      post '/sources/create', :name => 'create-source-test42', :uri => "http://create.42", :source_type => "file"
    end.should change(Source, :count).by(1)

    lambda do
      post '/sources/create', :name => 'create-source-test42', :uri => "http://create.42", :source_type => "file"
    end.should_not change(Source, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"

    # invalid source_type
    lambda do
      post '/sources/create', :name => 'create-source-test420', :uri => "http://create.420", :source_type => "xyz"
    end.should_not change(Source, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"
  end

  it "should allow source deletions" do
    post '/sources/create', :name => 'delete-source-test', :uri => 'http://delete.source.test', :source_type => 'gem'
    source_id = Source.find(:first, :conditions => ['name = ?', 'delete-source-test']).id
    lambda do
      delete "/sources/destroy/#{source_id}"
    end.should change(Source, :count).by(-1)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "true"
  end

  it "should return an error if source id to delete is invalid" do
    lambda do
      delete "/sources/destroy/abc"
    end.should_not change(Project, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"
  end

  # test triggering release event
  it "should successfully post-process a released source" do
      project   = Project.create! :name => 'myproj42'
      project.sources << Source.create!(:name => 'mysource', :source_type => 'file',
                                        :uri => 'http://my.source.uri')
      project.save!

      event = Event.create :project => project,
                           :process => "integration_test_handler6",
                           :version_qualifier => '=',
                           :version => "5.6"

      # since we don't specify source_id / project_id in project_source_versions above, the project
      # version used to trigger the events will be the same as the source version
      post '/sources/released', :name => 'mysource',
                                :version => "5.6"

      last_response.should be_ok
      LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "true"

      $integration_test_handler_flags.include?("5.6").should == true
  end

  it "should return an error if there is a problem in the project release process" do
      project   = Project.create :name => 'foobar142'
      project.sources << Source.create!(:name => 'mysource42', :source_type => 'file',
                                        :uri => 'http://my.source42.uri')
      project.save!

      event = Event.create :project => project,
                           :process => "failed_event_handler",
                           :version_qualifier => '=',
                           :version => 1.0


      # need to specify name and version
      post '/sources/released', :name => 'mysource42'
      last_response.should be_ok
      LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"

      post '/sources/released', :version => '1.0'
      last_response.should be_ok
      LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"

      # event handler should throw exception, which the app should return
      post '/sources/released', :name => 'mysource42',
                                :version => '1.0'
      last_response.should be_ok
      LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"
      LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "errors" }.content.strip.should =~ /.*MYERROR.*/
      LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "message" }.content.strip.should =~ /.*MYERROR.*/
  end

  it "should allow project source creations" do
    project = Project.create! :name => "create-project-source-testproject1"
    source  = Source.create!  :name => "create-project_source-testsource1", :source_type => 'file', :uri => 'http://cpsts1'

    lambda do
      post '/project_source_versions/create', :project_id => project.id, :source_id => source.id
    end.should change(ProjectSourceVersion, :count).by(1)
    ps = ProjectSourceVersion.find(:first, :conditions => [ 'project_id = ? AND source_id = ?', project.id, source.id])
    ps.should_not be_nil

    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "true"
  end

  it "should return an error if project source project_id or source_id is not specified on creation" do
    project = Project.create! :name => "create-project_source-test2"
    source  = Source.create!  :name => "create-project_source-testsource2", :source_type => 'file', :uri => 'http://cpsts10'

    lambda do
      post '/project_source_versions/create', :project_id => project.id
    end.should_not change(ProjectSourceVersion, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"

    lambda do
      post '/project_source_versions/create', :source_id => source.id
    end.should_not change(ProjectSourceVersion, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"
  end

  it "should return an error if project source project_id or source_id is invalid" do
    lambda do
      post '/project_source_versions/create', :project_id => 'abc'
    end.should_not change(ProjectSourceVersion, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"

    lambda do
      post '/project_source_versions/create', :source_id => 'def'
    end.should_not change(ProjectSourceVersion, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"
  end

  it "should allow project source deletions" do
    project = Project.create! :name => "create-project_source-test20"
    source  = Source.create!  :name => "create-project_source-testsource42", :source_type => 'file', :uri => 'http://cpsts20'
    post '/project_source_versions/create', :project_id => project.id, :source_id => source.id

    ps = ProjectSourceVersion.find(:first, :conditions => [ 'source_id = ? AND project_id = ?', source.id, project.id])
    lambda do
      delete "/project_source_versions/destroy/#{ps.id}"
    end.should change(ProjectSourceVersion, :count).by(-1)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "true"
  end

  it "should return an error if project source id to delete is invalid" do
    lambda do
      delete "/project_source_versions/destroy/abc"
    end.should_not change(ProjectSourceVersion, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"
  end

  it "should allow project event creations" do
    project = Project.create! :name => "create-event-test-project"
    lambda do
      post '/events/create', :project_id => project.id,
                             :process => 'fooproc',
                             :version => '1.0',
                             :version_qualifier => ">",
                             :process_options => 'opts'
    end.should change(Event, :count).by(1)
    Event.find(:first,
               :conditions => ['project_id = ? AND process = ? AND version = ? ' +
                               'AND version_qualifier = ? AND process_options = ?',
                               project.id, 'fooproc', '1.0', '>', 'opts']).should_not be_nil
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "true"
  end

  it "should return an error if event process id or process is missing or invalid on creation" do
    project = Project.create! :name => "create-event-test-project2"

    lambda do
      post '/events/create'
    end.should_not change(Event, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"

    lambda do
      post '/events/create', :process => "fooproc"
    end.should_not change(Event, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"

    lambda do
      post '/events/create', :project_id => project.id
    end.should_not change(Event, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"

    lambda do
      post '/events/create', :project_id => 'abc'
    end.should_not change(Event, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"
  end

  it "should allow event deletions" do
    proj  = Project.create :name => "delete-event-test-project"
    event = Event.create :project => proj, :process => 'fooproc'
    lambda do
      delete "/events/destroy/#{event.id}"
    end.should change(Event, :count).by(-1)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "true"
  end

  it "should return an error if event id to delete is invalid" do
    lambda do
      delete "/events/destroy/abc"
    end.should_not change(Event, :count)
    last_response.should be_ok
    LibXML::XML::Document.string(last_response.body).root.children.find { |c| c.name == "success" }.content.strip.should == "false"
  end

end

# prolly a better way todo this, but fine for now
$integration_test_handler_flags = []

def failed_event_handler(event, version, args = {})
  raise ArgumentError, "MYERROR"
end

def integration_test_handler1(event, version, args = {})
  $integration_test_handler_flags << 1
end

def integration_test_handler2(event, version, args = {})
  $integration_test_handler_flags << 2
end

def integration_test_handler3(event, version, args = {})
  $integration_test_handler_flags << 3
end

def integration_test_handler4(event, version, args = {})
  $integration_test_handler_flags << 4
end

def integration_test_handler5(event, version, args = {})
  args.each { |k,v|
    $integration_test_handler_flags << "#{k}#{v}"
  }
end

def integration_test_handler6(event, version, args = {})
  $integration_test_handler_flags << version
end
