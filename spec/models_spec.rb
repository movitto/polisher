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
  before(:each) do
    FileUtils.rm_rf(ARTIFACTS_DIR) if File.directory? ARTIFACTS_DIR
    FileUtils.mkdir_p(ARTIFACTS_DIR)
  end

  after(:each) do
    FileUtils.rm_rf(ARTIFACTS_DIR) if File.directory? ARTIFACTS_DIR
  end

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

  it "should provide access to all dependencies and dependent projects" do
    project1 = Project.create! :name => "project-dependency-tree1"
    project2 = Project.create! :name => "project-dependency-tree2"
    project3 = Project.create! :name => "project-dependency-tree3"
    project4 = Project.create! :name => "project-dependency-tree4"
    project5 = Project.create! :name => "project-dependency-tree5"

    pd1 = ProjectDependency.create! :project => project2, :depends_on_project => project1
    pd2 = ProjectDependency.create! :project => project3, :depends_on_project => project2
    pd3 = ProjectDependency.create! :project => project4, :depends_on_project => project2
    pd4 = ProjectDependency.create! :project => project4, :depends_on_project => project5

    deps = project1.dependencies
    deps.size.should == 0
    depts = project1.dependents
    depts.size.should == 1
    depts[0].project.id.should == project2.id

    deps = project2.dependencies
    deps.size.should == 1
    deps[0].depends_on_project.id.should == project1.id
    depts = project2.dependents
    depts.size.should == 2
    depts[0].project.id.should == project3.id
    depts[1].project.id.should == project4.id

    deps = project3.dependencies
    deps.size.should == 1
    deps[0].depends_on_project.id.should == project2.id
    depts = project3.dependents
    depts.size.should == 0

    deps = project4.dependencies
    deps.size.should == 2
    deps[0].depends_on_project.id.should == project2.id
    deps[1].depends_on_project.id.should == project5.id
    depts = project4.dependents
    depts.size.should == 0

    deps = project5.dependencies
    deps.size.should == 0
    depts = project5.dependents
    depts.size.should == 1
    depts[0].project.id.should == project4.id
  end

  it "should download all sources" do
    project = Project.create! :name => 'project-dl-test100'

    # see FIXME in Project::download_to
    source1 = Source.create!  :name => 'jffi-spec', :uri => 'http://mo.morsi.org/files/jruby/jffi.spec', :source_type => 'spec'
    source2 = Source.create!  :name => 'joni-spec', :uri => 'http://mo.morsi.org/files/jruby/joni.spec', :source_type => 'spec'

    ps1 = ProjectSourceVersion.create! :project => project, :source => source1
    ps2 = ProjectSourceVersion.create! :project => project, :source => source2, :project_version => "1.5"

    project.download_to :dir => ARTIFACTS_DIR

    File.size?(ARTIFACTS_DIR + '/joni.spec').should_not be_nil
    File.size?(ARTIFACTS_DIR + '/jffi.spec').should_not be_nil
  end

  it "should download all sources for specified version" do
    project = Project.new :name => 'project-dl-test100'
    source1 = Source.new  :name => 'jffi-spec', :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/jffi.spec', :source_type => 'spec'
    source2 = Source.new  :name => 'joni-spec', :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/joni.spec', :source_type => 'spec'

    ps1 = ProjectSourceVersion.new :project => project, :source => source1, :project_version => "1.6", :source_uri_params => "cluster=jruby;filetype=spec"
    ps2 = ProjectSourceVersion.new :project => project, :source => source2, :project_version => "1.5", :source_uri_params => "cluster=jruby;dir=files"
    project.project_source_versions << ps1 << ps2

    project.download_to :version => "1.5", :dir => ARTIFACTS_DIR

    File.size?(ARTIFACTS_DIR + '/joni.spec').should_not be_nil
    File.size?(ARTIFACTS_DIR + '/jffi.spec').should be_nil
  end

  it "should return all events for the specified version" do
    project = Project.new :name => 'project-dl-test100'
    event1  = Event.new :version_qualifier => "=", :version => "1.5"
    event2  = Event.new :version_qualifier => ">", :version => "1.6"
    project.events << event1 << event2

    events = project.events_for_version("1.5")
    events.size.should == 1
    events.include?(event1).should be_true
    events.include?(event2).should be_false
  end

  it "should return all project_source_versions for the specified version" do
    project = Project.new :name => 'project-dl-test100'
    source1 = Source.new  :name => 'jffi-spec', :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/jffi.spec', :source_type => 'spec'
    source2 = Source.new  :name => 'joni-spec', :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/joni.spec', :source_type => 'spec'
    source3 = Source.new  :name => 'jruby-spec', :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/jruby.spec', :source_type => 'spec'

    ps1 = ProjectSourceVersion.new :project => project, :source => source1, :project_version => '1.6', :source_uri_params => "cluster=jruby;filetype=spec"
    ps2 = ProjectSourceVersion.new :project => project, :source => source2, :project_version => "1.5", :source_uri_params => "cluster=jruby;dir=files"
    ps3 = ProjectSourceVersion.new :project => project, :source => source3, :source_uri_params => "cluster=jruby;filetype=spec"
    project.project_source_versions << ps1 << ps2 << ps3

    project_sources = project.project_source_versions_for_version("1.5")
    project_sources.size.should == 2
    project_sources.include?(ps1).should be_false
    project_sources.include?(ps2).should be_true
    project_sources.include?(ps3).should be_true
  end

  it "should return all sources for the specified version with formatted uris" do
    project = Project.new :name => 'project-dl-test100'
    source1 = Source.new  :name => 'jffi-spec',  :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/jffi.spec',  :source_type => 'spec'
    source2 = Source.new  :name => 'joni-spec',  :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/joni.spec',  :source_type => 'spec'
    source3 = Source.new  :name => 'jruby-spec', :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/jruby.spec', :source_type => 'spec'

    ps1 = ProjectSourceVersion.new :project => project, :source => source1, :project_version => "1.6", :source_uri_params => "cluster=jruby;filetype=spec"
    ps2 = ProjectSourceVersion.new :project => project, :source => source2, :project_version => "1.5", :source_uri_params => "cluster=jruby;dir=files"
    ps3 = ProjectSourceVersion.new :project => project, :source => source3, :source_uri_params => "cluster=jruby;dir=files"
    project.project_source_versions << ps1 << ps2 << ps3

    sources = project.sources_for_version("1.5")
    sources.size.should == 2
    sources.include?(source1).should be_false
    sources.include?(source2).should be_true
    sources.include?(source3).should be_true

    sources[0].uri.should == "http://mo.morsi.org/files/jruby/joni.spec"
    sources[1].uri.should == "http://mo.morsi.org/files/jruby/jruby.spec"
  end

  it "should provide access to primary source" do
    project = Project.create! :name => 'primary-source-project-test'
    source1 = Source.create!(:name => 'primary-source-test1', :source_type => 'file', :uri => 'http://foo1.foo')
    source2 = Source.create!(:name => 'primary-source-test2', :source_type => 'file', :uri => 'http://foo2.foo')
    project.sources << source1
    project.primary_source= source2

    primary_src = project.primary_source
    primary_src.should_not be_nil
    primary_src.name.should == source2.name
  end

  it "should provide access to all dependencies for the specified version" do
    project1 = Project.create! :name => "project-dependency-tree10"
    project2 = Project.create! :name => "project-dependency-tree20"
    project3 = Project.create! :name => "project-dependency-tree30"
    project4 = Project.create! :name => "project-dependency-tree40"

    pd1 = ProjectDependency.create! :project => project1, :depends_on_project => project2, :project_version => "1.0.0"
    pd2 = ProjectDependency.create! :project => project1, :depends_on_project => project3, :project_version => "2.0.0"
    pd2 = ProjectDependency.create! :project => project1, :depends_on_project => project4

    deps = project1.dependencies_for_version("1.0.0")
    deps.size.should == 2
    deps[0].depends_on_project.id.should == project2.id
    deps[1].depends_on_project.id.should == project4.id
  end

  it "should return all versions which the project is configured for" do
    project = Project.new :name => 'project-dl-test100'
    event1  = Event.new :version_qualifier => "=", :version => "1.5"
    event2  = Event.new :version_qualifier => ">", :version => "1.6"
    project.events << event1 << event2

    source1 = Source.new  :name => 'jffi-spec',  :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/jffi.spec',  :source_type => 'spec'
    source2 = Source.new  :name => 'joni-spec',  :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/joni.spec',  :source_type => 'spec'
    source3 = Source.new  :name => 'jruby-spec', :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/jruby.spec', :source_type => 'spec'
    ps1 = ProjectSourceVersion.new :project => project, :source => source1, :source_uri_params => "cluster=jruby;filetype=spec"
    ps2 = ProjectSourceVersion.new :project => project, :source => source2, :project_version => "1.5", :source_uri_params => "cluster=jruby;dir=files"
    ps3 = ProjectSourceVersion.new :project => project, :source => source3, :project_version => "1.7", :source_uri_params => "cluster=jruby;dir=files"
    project.project_source_versions << ps1 << ps2 << ps3

    projectd = Project.new :name => 'project-version-test99'
    project.project_dependencies << ProjectDependency.new(:project => project, :depends_on_project => projectd, :project_version => "9.9")

    versions = project.versions
    versions.size.should == 4
    versions.include?("1.5").should be_true
    versions.include?("1.6").should be_true
    versions.include?("1.7").should be_true
    versions.include?("9.9").should be_true
  end

  it "should trigger dependencies and events upon release" do
    project   = Project.create :name => 'project-release-test-199'

    Event.create :project => project,
                 :process => "project_released_test_handlerAAA",
                 :version_qualifier => '=',
                 :version => "5.6"

    Event.create :project => project,
                 :process => "project_released_test_handlerBBB",
                 :version_qualifier => '>',
                 :version => "7.9"

    projectd1 = Project.create :name => 'project-release-test-299'
    Event.create :project => projectd1,
                 :process => "project_released_test_handlerDDD"
    Event.create :project => projectd1,
                 :process => "project_released_test_handlerEEE",
                 :version_qualifier => "=",
                 :version => "1.9"

    projectd2 = Project.create :name => 'project-release-test-399'
    Event.create :project => projectd2,
                 :process => "project_released_test_handlerFFF",
                 :version_qualifier => "=",
                 :version => "1.9"
    Event.create :project => projectd2,
                 :process => "project_released_test_handlerGGG",
                 :version_qualifier => "=",
                 :version => "6.5"

    projectd3 = Project.create :name => 'project-release-test-499'
    Event.create :project => projectd3,
                 :process => "project_released_test_handlerCCC"

    pd1 = ProjectDependency.new :project => project, :depends_on_project => projectd1, :depends_on_project_params => "jim=bo;john=mark"
    pd2 = ProjectDependency.new :project => project, :depends_on_project => projectd2, :project_version => "5.6", :depends_on_project_version => "6.5"
    pd3 = ProjectDependency.new :project => project, :depends_on_project => projectd3, :project_version => "7.9"
    project.project_dependencies << pd1 << pd2 << pd3

    project.released_version("5.6", :joe => 'bob', :sam => 'sue')

    $project_released_test_handler_flags.include?('AAA').should be_true
    $project_released_test_handler_flags.include?('BBB').should be_false
    $project_released_test_handler_flags.include?('CCC').should be_false
    $project_released_test_handler_flags.include?('DDD').should be_true
    $project_released_test_handler_flags.include?('EEE').should be_true
    $project_released_test_handler_flags.include?('FFF').should be_false
    $project_released_test_handler_flags.include?('GGG').should be_true
    $project_released_test_handler_flags.include?('joe=bob').should be_true
    $project_released_test_handler_flags.include?('sam=sue').should be_true
    $project_released_test_handler_flags.include?('jim=bo').should be_true
    $project_released_test_handler_flags.include?('john=mark').should be_true
  end
end

describe "Polisher::Source" do
  before(:each) do
    FileUtils.rm_rf(ARTIFACTS_DIR) if File.directory? ARTIFACTS_DIR
    FileUtils.mkdir_p(ARTIFACTS_DIR)
  end

  after(:each) do
    FileUtils.rm_rf(ARTIFACTS_DIR) if File.directory? ARTIFACTS_DIR
  end

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

  it "should return filename generated from uri" do
     source = Source.new(
        :uri => 'http://mo.morsi.org/files/jruby/joni-123.spec?addition=foo&params=bar',
        :name => "joni-spec", :source_type => "spec")
     source.filename.should == "joni-123.spec"
  end

  it "should return all project_source_versions for the specified version" do
    project1 = Project.new :name => 'project-src-p100'
    project2 = Project.new :name => 'project-src-p101'
    project3 = Project.new :name => 'project-src-p102'
    source = Source.new  :name => 'jffi-spec', :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/jffi.spec', :source_type => 'spec'

    ps1 = ProjectSourceVersion.new :project => project1, :source => source, :source_uri_params => "cluster=jruby;filetype=spec"
    ps2 = ProjectSourceVersion.new :project => project2, :source => source, :project_version => "1.5", :source_uri_params => "cluster=jruby;dir=files"
    ps3 = ProjectSourceVersion.new :project => project3, :source => source, :project_version => "1.6", :source_uri_params => "cluster=jruby;dir=files"
    source.project_source_versions << ps1 << ps2

    project_sources = source.project_source_versions_for_version("1.5")
    project_sources.size.should == 2
    project_sources.include?(ps1).should be_true
    project_sources.include?(ps2).should be_true
    project_sources.include?(ps3).should be_false
  end

  it "should return all projects for the specified version" do
    project1 = Project.new :name => 'project-src-p100'
    project2 = Project.new :name => 'project-src-p101'
    project3 = Project.new :name => 'project-src-p102'
    source = Source.new  :name => 'jffi-spec', :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/jffi.spec', :source_type => 'spec'

    ps1 = ProjectSourceVersion.new :project => project1, :source => source, :source_uri_params => "cluster=jruby;filetype=spec"
    ps2 = ProjectSourceVersion.new :project => project2, :source => source, :source_version => "1.5", :source_uri_params => "cluster=jruby;dir=files"
    ps3 = ProjectSourceVersion.new :project => project3, :source => source, :source_version => "1.6", :source_uri_params => "cluster=jruby;dir=files"
    source.project_source_versions << ps1 << ps2 << ps3

    projects = source.project_source_versions_for_version("1.5")
    projects.size.should == 2
    projects.collect { |p| p.source_version }.include?(nil).should be_true
    projects.collect { |p| p.source_version }.include?("1.5").should be_true
    projects.collect { |p| p.source_version }.include?("1.6").should be_false

    projects.collect { |p| p.project.name }.include?("project-src-p100").should be_true
    projects.collect { |p| p.project.name }.include?("project-src-p101").should be_true
    projects.collect { |p| p.project.name }.include?("project-src-p102").should be_false
  end

  it "should return all versions which the source is configured for" do
    project1 = Project.new :name => 'project-src-p100'
    project2 = Project.new :name => 'project-src-p101'
    project3 = Project.new :name => 'project-src-p102'
    source = Source.new  :name => 'jffi-spec', :uri => 'http://mo.morsi.org/%{dir}/%{cluster}/jffi.spec', :source_type => 'spec'

    ps1 = ProjectSourceVersion.new :project => project1, :source => source, :source_uri_params => "cluster=jruby;filetype=spec"
    ps2 = ProjectSourceVersion.new :project => project2, :source => source, :source_version => "1.5", :source_uri_params => "cluster=jruby;dir=files"
    ps3 = ProjectSourceVersion.new :project => project3, :source => source, :source_version => "1.6", :source_uri_params => "cluster=jruby;dir=files"
    source.project_source_versions << ps1 << ps2 << ps3

    versions = source.versions
    versions.size.should == 2
    versions.include?("1.5").should be_true
    versions.include?("1.6").should be_true
  end

  it "should format the uri w/ the specified variables" do
    source = Source.new :uri => "http://%{var1}.%{var2}/%{another}?%{yet_another}=%{even_more}&%{last}"
    source.format_uri! :var1 => 'val1', :var2 => 'val2',
                       :another => 'foo', :yet_another => 'bar',
                       :even_more => 'something', :last => '123'

    source.uri.should == "http://val1.val2/foo?bar=something&123"
  end

  it "should be downloadable" do
     source = Source.new(
        :uri => 'http://mo.morsi.org/files/jruby/joni.spec',
        :name => "joni-spec", :source_type => "spec")
     path = source.download_to(:dir => ARTIFACTS_DIR)
     File.size?(ARTIFACTS_DIR + '/joni.spec').should_not be_nil
     FileUtils.rm(ARTIFACTS_DIR + '/joni.spec')
     path.should == ARTIFACTS_DIR + '/joni.spec'

     source.download_to(:path => ARTIFACTS_DIR + '/joni.spec')
     File.size?(ARTIFACTS_DIR + '/joni.spec').should_not be_nil
  end

  it "should permit a parameterized download" do
     source = Source.new(
        :uri => 'http://mo.morsi.org/files/%{group}/%{name}.spec',
        :name => "joni-spec", :source_type => 'spec')
     path = source.download_to(:dir => ARTIFACTS_DIR, :group => "jruby", :name => "joni")
     File.size?(ARTIFACTS_DIR + '/joni.spec').should_not be_nil
     FileUtils.rm(ARTIFACTS_DIR + '/joni.spec')
     path.should == ARTIFACTS_DIR + '/joni.spec'

     source.download_to(:path => ARTIFACTS_DIR + '/joni.spec')
     File.size?(ARTIFACTS_DIR + '/joni.spec').should_not be_nil
  end

  it "should raise an exception if download source uri or destination path is invalid" do
     source = Source.new(
        :uri => 'http://invalid.uri',
        :name => 'invalid-source1', :source_type => 'file')
     lambda {
       path = source.download_to(:dir => ARTIFACTS_DIR)
     }.should raise_error(RuntimeError)

     source = Source.new(
        :uri => 'http://mo.morsi.org/files/jruby/joni.spec',
        :name => 'invalid-source2', :source_type => 'spec')
     lambda {
       path = source.download_to(:dir => '/')
     }.should raise_error(RuntimeError)

     lambda {
       path = source.download_to(:dir => '/nonexistantfoobar')
     }.should raise_error(RuntimeError)
  end
end

describe "Polisher::ProjectSourceVersion" do

   it "should default primary_source to false" do
    project = Project.create! :name => 'project-source-valid-testproj0'
    source  = Source.create!  :name => 'project-source-valid-testsource0',
                              :uri  => 'http://presvts234', :source_type => 'file'
    ps = ProjectSourceVersion.create! :project => project, :source => source
    ps.primary_source.should be_false
   end

   it "should default versions to nil" do
    project = Project.create! :name => 'project-source-valid-testproj10'
    source  = Source.create!  :name => 'project-source-valid-testsource10',
                              :uri  => 'http://presvts098', :source_type => 'file'
    ps = ProjectSourceVersion.create! :project => project, :source => source, :project_version => "", :source_version => ""
    ps.project_version.should be_nil
    ps.source_version.should be_nil
   end

   it "should not be valid if a project id/version is associated w/ a source multiple times" do
    project = Project.create! :name => 'project-source-valid-testproj1'
    source  = Source.create!  :name => 'project-source-valid-testsource1',
                              :uri  => 'http://presvts581', :source_type => 'file'

    ps1 = ProjectSourceVersion.create! :project => project, :source => source, :project_version => '1.6'
    ps2 = ProjectSourceVersion.new :project => project, :source => source, :project_version => '1.6'

    ps2.valid?.should be_false
   end

   it "should not be valid if a project id/version is associated w/ multiple primary sources" do
    project = Project.create! :name => 'project-source-valid-testproj2'
    source1 = Source.create!  :name => 'project-source-valid-testsource100',
                              :uri  => 'http://presvts690', :source_type => 'file'
    source2 = Source.create!  :name => 'project-source-valid-testsource200',
                              :uri  => 'http://presvts456', :source_type => 'file'

    ps1 = ProjectSourceVersion.create! :project => project, :source => source1, :project_version => '1.6',
                                 :primary_source => true

    ps2 = ProjectSourceVersion.new :project => project, :source => source2, :project_version => '1.6',
                                 :primary_source => true

    ps2.valid?.should be_false
   end

end

describe "Polisher::ProjectDependency" do

  it "should default versions to nil" do
    project1 = Project.create! :name => 'project-dep-valid-testproj10'
    project2 = Project.create! :name => 'project-dep-valid-testproj20'

    pd = ProjectDependency.create! :project => project1, :depends_on_project => project2
    pd.project_version.should be_nil
    pd.depends_on_project_version.should be_nil
  end

  it "should not be valid if missing project or depends_on_project" do
    project1 = Project.create! :name => 'project-dep-valid-testproj30'
    project2 = Project.create! :name => 'project-dep-valid-testproj40'

    pd = ProjectDependency.new
    pd.should_not be_valid

     
    pd = ProjectDependency.new :project => project1
    pd.should_not be_valid

    pd = ProjectDependency.new :depends_on_project => project2
    pd.should_not be_valid

    pd = ProjectDependency.new :project => project1, :depends_on_project => project2
    pd.should be_valid
  end

  it "should not be valid if project/depends_on_project/project_version/depends_on_project_version are not unique" do
    project1 = Project.create! :name => 'project-dep-valid-testproj50'
    project2 = Project.create! :name => 'project-dep-valid-testproj60'

    pd = ProjectDependency.create! :project => project1, :depends_on_project => project2, :project_version => "1.0.0", :depends_on_project_version => "2.0.1"

    pd2 = ProjectDependency.new :project => project1, :depends_on_project => project2, :project_version => "1.0.0", :depends_on_project_version => "2.0.1"
    pd2.should_not be_valid

    pd2.depends_on_project_version = "2.0.2"
    pd2.should be_valid
  end

end

describe "Polisher::Event" do

   it "should return list of supported event handlers" do
     processes = Event::processes
     processes.size.should == 2
     processes.include?("create_rpm_package").should be_true
     processes.include?("update_yum_repo").should be_true
   end

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

      # nil event version and version_qualifier is permitted
      #lambda {
      #  event.applies_to_version?('0.5.2')
      #}.should raise_error(ArgumentError)

      event.version = '0.7'
      lambda {
        event.applies_to_version?(111)
      }.should raise_error(ArgumentError)
   end

   it "should successfully run event process" do
      project = Project.new :name => "foobar"
      event = Event.new :project => project, :process => "test_event_run_method"
      event.run(:version => "5.0", :key1 => "val1", :some => "thing", :answer => 42)

      $test_event_run_hash[:event].should_not be_nil
      $test_event_run_hash[:project].should_not be_nil
      $test_event_run_hash[:version].should_not be_nil
      $test_event_run_hash[:key1].should_not be_nil
      $test_event_run_hash[:some].should_not be_nil
      $test_event_run_hash[:answer].should_not be_nil

      $test_event_run_hash[:event].process == "test_event_run_method"
      $test_event_run_hash[:project].name.should == "foobar"
      $test_event_run_hash[:version].should == "5.0"
      $test_event_run_hash[:key1].should == "val1"
      $test_event_run_hash[:some].should == "thing"
      $test_event_run_hash[:answer].should == 42
   end

   it "should raise an exception if running event w/out specifying version" do
      project = Project.new :name => "foobar"
      event = Event.new :project => project, :process => "test_event_run_method"
      lambda {
        event.run
      }.should raise_error(ArgumentError)
   end

   it "should raise an exception if running event process that doesn't correspond to a method" do
      project = Project.new :name => "foobar"
      event = Event.new :project => project, :process => "non_existant_method"
      lambda {
        event.run :version => "5"
      }.should raise_error(ArgumentError)
   end

   it "should raise an exception if event process being run does" do
      project = Project.new :name => "foobar"
      event = Event.new :project => project, :process => "error_generating_method"
      lambda {
        event.run :version => "5"
      }.should raise_error(RuntimeError)
   end
end

# prolly should fixure out a better way todo this
$test_event_run_hash = {}

# helper method, invoked in Event::run spec
def test_event_run_method(event, version, args = {})
  $test_event_run_hash[:event]   = event
  $test_event_run_hash[:project] = event.project
  $test_event_run_hash[:version] = version
  $test_event_run_hash[:key1]   = args[:key1]
  $test_event_run_hash[:some]   = args[:some]
  $test_event_run_hash[:answer] = args[:answer]
end

def error_generating_method(event, version, args = {})
  raise RuntimeError
end

$project_released_test_handler_flags = []

def project_released_test_handlerAAA(event, version, args = {})
  $project_released_test_handler_flags << "AAA"
end

def project_released_test_handlerBBB(event, version, args = {})
  $project_released_test_handler_flags << "BBB"
end

def project_released_test_handlerCCC(event, version, args = {})
  $project_released_test_handler_flags << "CCC"
end

def project_released_test_handlerDDD(event, version, args = {})
  $project_released_test_handler_flags << "DDD"

  args.each { |k,v|
    $project_released_test_handler_flags << "#{k}=#{v}"
  }
end

def project_released_test_handlerEEE(event, version, args = {})
  $project_released_test_handler_flags << "EEE"
end

def project_released_test_handlerFFF(event, version, args = {})
  $project_released_test_handler_flags << "FFF"
end

def project_released_test_handlerGGG(event, version, args = {})
  $project_released_test_handler_flags << "GGG"
end

