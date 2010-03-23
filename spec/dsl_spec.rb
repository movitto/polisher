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

require File.dirname(__FILE__) + '/spec_helper'

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
#gem(:name => 'myproject').updated_version "2.0"
#gem(:name => 'myproject').updated_version "1.5"
#project(:name => "official ruby").released :rubyxver => '1.8', :arcver => '1.8.6-p388"

describe "Polisher::dsl" do
   it "" do
   end
end
