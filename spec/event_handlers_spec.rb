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

describe "Polisher::EventHandlers" do
 
  before(:each) do
     FileUtils.rm_rf(ARTIFACTS_DIR)
     FileUtils.mkdir_p(ARTIFACTS_DIR + '/gems')
     FileUtils.mkdir_p(ARTIFACTS_DIR + '/repos')
     FileUtils.mkdir_p(ARTIFACTS_DIR + '/SOURCES')
     FileUtils.mkdir_p(ARTIFACTS_DIR + '/SPECS')
     FileUtils.mkdir_p(ARTIFACTS_DIR + '/templates')

     unless defined? @gem
       @gem = ManagedGem.create :name => 'polisher', :source_id => 1
     end
  end

  it "should correctly create package" do
     create_package(@gem)
     File.exists?(ARTIFACTS_DIR + '/gems/polisher-0.3.gem').should == true
     File.exists?(ARTIFACTS_DIR + '/SOURCES/polisher-0.3.gem').should == true
     File.exists?(ARTIFACTS_DIR + '/SPECS/rubygem-polisher.spec').should == true
     File.exists?(ARTIFACTS_DIR + "/SRPMS/rubygem-polisher-0.3-1.#{BUILD_VERSION}.src.rpm").should == true
     File.exists?(ARTIFACTS_DIR + "/RPMS/noarch/rubygem-polisher-0.3-1.#{BUILD_VERSION}.noarch.rpm").should == true
  end

  it "should correctly create package using template" do
    File.write(ARTIFACTS_DIR + '/templates/polisher.spec.tpl', POLISHER_TEST_TEMPLATE)
    create_package(@gem, '/polisher.spec.tpl')
    File.exists?(ARTIFACTS_DIR + '/SPECS/rubygem-polisher.spec').should == true
    File.read_all(ARTIFACTS_DIR + '/SPECS/rubygem-polisher.spec').should =~ /.*by polisher.*/
  end

  it "should correctly update repository" do
     create_package(@gem)
     update_repo(@gem, 'fedora-ruby')
     File.directory?(ARTIFACTS_DIR + '/repos/fedora-ruby/noarch').should == true
     File.directory?(ARTIFACTS_DIR + '/repos/fedora-ruby/repodata').should == true
     File.exists?(ARTIFACTS_DIR + '/repos/fedora-ruby/noarch/rubygem-polisher.rpm').should == true
     File.exists?(ARTIFACTS_DIR + '/repos/fedora-ruby/repodata/repomd.xml').should == true
     File.exists?(ARTIFACTS_DIR + '/repos/fedora-ruby/repodata/primary.xml.gz').should == true
     File.exists?(ARTIFACTS_DIR + '/repos/fedora-ruby/repodata/other.xml.gz').should == true
     File.exists?(ARTIFACTS_DIR + '/repos/fedora-ruby/repodata/filelists.xml.gz').should == true
  end

  it "should correctly notify email recipients" do
     # TODO test notify subscribers
     #notify_subscribers(@gem, [...])
  end

end

POLISHER_TEST_TEMPLATE =
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
