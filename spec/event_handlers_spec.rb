# ruby gem polisher event handlers spec
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
# General Public License, along with Motel. If not, see 
# <http://www.gnu.org/licenses/>

require 'fileutils'

require File.dirname(__FILE__) + '/spec_helper'

BUILD_VERSION='fc11'

include EventHandlers

describe "EventHandlers" do

  before(:all) do
    @gem = Project.create! :name => 'rubygem-polisher'
    @gem.primary_source = Source.new :name => 'polisher', :source_type => 'gem', :uri => 'http://rubygems.org/gems/polisher-%{version}.gem'
    @gem_event1 = Event.create! :project => @gem, :process => 'create_rpm_package'

    @gem_event2 = Event.create! :project => @gem, :process => 'create_rpm_package',
                                :process_options => ARTIFACTS_DIR + '/templates/polisher.spec.tpl'

    @gem_event3 = Event.create! :project => @gem, :process => 'update_repo', :process_options => "#{ARTIFACTS_DIR}/repos/fedora-ruby"

    @project = Project.create :name => 'ruby-activerecord'
    @project.sources << Source.new(:name => 'activerecord', :source_type => 'file',
          :uri     => 'http://rubyforge.org/frs/download.php/28874/activerecord-%{version}.tgz')

    @project_event1 = Event.create! :project => @project, :process => 'create_rpm_package',
                                    :process_options => ARTIFACTS_DIR + '/templates/polisher-projects.spec.tpl'

    @project_event2 = Event.create! :project => @project, :process => 'update_repo', :process_options => "#{ARTIFACTS_DIR}/repos/fedora-ruby"
  end
 
  before(:each) do
     FileUtils.rm_rf(ARTIFACTS_DIR)
     FileUtils.mkdir_p(ARTIFACTS_DIR + '/repos')
     FileUtils.mkdir_p(ARTIFACTS_DIR + '/SOURCES')
     FileUtils.mkdir_p(ARTIFACTS_DIR + '/SPECS')
     FileUtils.mkdir_p(ARTIFACTS_DIR + '/templates')

    File.write(ARTIFACTS_DIR + '/templates/polisher.spec.tpl', POLISHER_GEM2RPM_TEST_TEMPLATE)
    File.write(ARTIFACTS_DIR + '/templates/polisher-projects.spec.tpl', POLISHER_ERB_TEST_TEMPLATE)
  end

  it "should correctly create a gem based package" do
     create_rpm_package(@gem_event1, "0.3")
     File.exists?(ARTIFACTS_DIR + '/SOURCES/polisher-0.3.gem').should == true
     File.exists?(ARTIFACTS_DIR + '/SPECS/rubygem-polisher.spec').should == true
     File.exists?(ARTIFACTS_DIR + "/SRPMS/rubygem-polisher-0.3-1.#{BUILD_VERSION}.src.rpm").should == true
     File.exists?(ARTIFACTS_DIR + "/RPMS/noarch/rubygem-polisher-0.3-1.#{BUILD_VERSION}.noarch.rpm").should == true
  end

  it "should correctly create a gem based package using template" do
    create_rpm_package(@gem_event2, '0.3')
    File.exists?(ARTIFACTS_DIR + '/SPECS/rubygem-polisher.spec').should == true
    File.read_all(ARTIFACTS_DIR + '/SPECS/rubygem-polisher.spec').should =~ /.*by polisher.*/
  end

  it "should correctly create an upstream based project package" do
    create_rpm_package(@project_event1, "2.0.1", :release => 3)

    File.exists?(ARTIFACTS_DIR + '/SOURCES/activerecord-2.0.1.tgz').should == true
    File.exists?(ARTIFACTS_DIR + '/SPECS/ruby-activerecord.spec').should == true
    File.exists?(ARTIFACTS_DIR + "/SRPMS/ruby-activerecord-2.0.1-3.#{BUILD_VERSION}.src.rpm").should == true
    File.exists?(ARTIFACTS_DIR + "/RPMS/noarch/ruby-activerecord-2.0.1-3.#{BUILD_VERSION}.noarch.rpm").should == true
  end

  it "should correctly update repository" do
     create_rpm_package(@gem_event1, '0.3')
     update_yum_repo(@gem_event3, '0.3')

     template = ARTIFACTS_DIR + '/templates/polisher-projects.spec.tpl'
     File.write(template, POLISHER_ERB_TEST_TEMPLATE)
     create_rpm_package(@project_event1, "2.0.1", :release => 3)
     update_yum_repo(@project_event2, '2.0')

     File.directory?(ARTIFACTS_DIR + '/repos/fedora-ruby/noarch').should == true
     File.directory?(ARTIFACTS_DIR + '/repos/fedora-ruby/repodata').should == true
     File.exists?(ARTIFACTS_DIR + '/repos/fedora-ruby/noarch/rubygem-polisher.rpm').should == true
     File.exists?(ARTIFACTS_DIR + '/repos/fedora-ruby/noarch/ruby-activerecord.rpm').should == true
     File.exists?(ARTIFACTS_DIR + '/repos/fedora-ruby/repodata/repomd.xml').should == true
     File.exists?(ARTIFACTS_DIR + '/repos/fedora-ruby/repodata/primary.xml.gz').should == true
     File.exists?(ARTIFACTS_DIR + '/repos/fedora-ruby/repodata/other.xml.gz').should == true
     File.exists?(ARTIFACTS_DIR + '/repos/fedora-ruby/repodata/filelists.xml.gz').should == true
  end

end

POLISHER_GEM2RPM_TEST_TEMPLATE =
%q{# Generated from <%= File::basename(format.gem_path) %> by polisher -*- rpm-spec -*-
%define ruby_sitelib %(ruby -rrbconfig -e "puts Config::CONFIG['sitelibdir']")
%define gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%define gemname <%= spec.name %>
%define geminstdir %{gemdir}/gems/%{gemname}-%{version}

Summary: <%= spec.summary.gsub(/\.$/, "") %>
Name: rubygem-%{gemname}
Version: <%= spec.version %>
Release: 1%{?dist}
Group: Development/Languages
License: GPLv2+ or Ruby
URL: <%= spec.homepage %>
Source0: <%= download_path %>%{gemname}-%{version}.gem
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires: rubygems
<% for d in spec.dependencies %>
<% for req in d.version_requirements.to_rpm %>
Requires: rubygem(<%= d.name %>) <%= req  %>
<% end %>
<% end %>
BuildRequires: rubygems
<% if spec.extensions.empty? %>
BuildArch: noarch
<% end %>
Provides: rubygem(%{gemname}) = %{version}

%description
<%= spec.description.to_s.chomp.word_wrap(78) + "\n" %>

<% if nongem %>
%package -n ruby-%{gemname}
Summary: <%= spec.summary.gsub(/\.$/, "") %>
Group: Development/Languages
Requires: rubygem(%{gemname}) = %{version}
<% spec.files.select{ |f| spec.require_paths.include?(File::dirname(f)) }.reject { |f| f =~ /\.rb$/ }.collect { |f| File::basename(f) }.each do |p| %>
Provides: ruby(<%= p %>) = %{version}
<% end %>
%description -n ruby-%{gemname}
<%= spec.description.to_s.chomp.word_wrap(78) + "\n" %>
<% end # if nongem %>

%prep

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{gemdir}
<% rdoc_opt = spec.has_rdoc ? "--rdoc " : "" %>
gem install --local --install-dir %{buildroot}%{gemdir} \
            --force <%= rdoc_opt %>%{SOURCE0}
<% unless spec.executables.empty? %>
mkdir -p %{buildroot}/%{_bindir}
mv %{buildroot}%{gemdir}/bin/* %{buildroot}/%{_bindir}
rmdir %{buildroot}%{gemdir}/bin
find %{buildroot}%{geminstdir}/bin -type f | xargs chmod a+x
<% end %>
<% if nongem %>
mkdir -p %{buildroot}%{ruby_sitelib}
<% spec.files.select{ |f| spec.require_paths.include?(File::dirname(f)) }.each do |p| %>
ln -s %{gemdir}/gems/%{gemname}-%{version}/<%= p %> %{buildroot}%{ruby_sitelib}
<% end %>
<% end # if nongem %>

%clean
rm -rf %{buildroot}

%files
%defattr(-, root, root, -)
<% for f in spec.executables %>
%{_bindir}/<%= f %>
<% end %>
%{gemdir}/gems/%{gemname}-%{version}/
<% if spec.has_rdoc %>
%doc %{gemdir}/doc/%{gemname}-%{version}
<% end %>
<% for f in spec.extra_rdoc_files %>
%doc %{geminstdir}/<%= f %>
<% end %>
%{gemdir}/cache/%{gemname}-%{version}.gem
%{gemdir}/specifications/%{gemname}-%{version}.gemspec

<% if nongem %>
%files -n ruby-%{gemname}
%defattr(-, root, root, -)
%{ruby_sitelib}/*
<% end # if nongem %>

%changelog
* <%= Time.now.strftime("%a %b %d %Y") %> <%= packager %> - <%= spec.version %>-1
- Initial package
}

# copied w/ changes from http://cvs.fedoraproject.org/viewvc/rpms/ruby-activerecord/F-13/ruby-activerecord.spec?revision=1.6&view=co
POLISHER_ERB_TEST_TEMPLATE =
%q{
%{!?ruby_sitelib: %define ruby_sitelib %(ruby -rrbconfig -e "puts Config::CONFIG['sitelibdir']")}
%define rname activerecord
# Only run the tests on distros that have sqlite3
%define with_check 0

Name:           ruby-%{rname}
Version:        <%= version %>
Release:        <%= release %>%{?dist}
Summary:        Implements the ActiveRecord pattern for ORM

Group:          Development/Languages

License:        MIT
URL:            http://rubyforge.org/projects/activerecord/
Source0:        http://rubyforge.org/frs/download.php/28874/activerecord-%{version}.tgz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildArch:      noarch
BuildRequires:  ruby >= 1.8
%if %with_check
BuildRequires:  ruby(active_support) = 2.0.1
BuildRequires:  ruby(sqlite3)
%endif
Requires:       ruby(abi) = 1.8
Requires:       ruby(active_support) = 2.0.1
Provides:       ruby(active_record) = %{version}

%description
Implements the ActiveRecord pattern (Fowler, PoEAA) for ORM. It ties
database tables and classes together for business objects, like Customer or
Subscription, that can find, save, and destroy themselves without resorting
to manual SQL.


%prep
%setup -q -n %{rname}-%{version}
chmod 0644 README

%build

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT/%{ruby_sitelib}/
cp -pr lib/* $RPM_BUILD_ROOT/%{ruby_sitelib}/
find $RPM_BUILD_ROOT/%{ruby_sitelib} -type f | xargs chmod a-x

%check
%if %with_check
cd test
ruby -I "connections/native_sqlite3" base_test.rb
%endif

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%{ruby_sitelib}/activerecord.rb
%{ruby_sitelib}/active_record.rb
%{ruby_sitelib}/active_record
%doc README CHANGELOG examples/
}
