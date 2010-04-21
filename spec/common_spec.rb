# polisher common spec
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

describe "Polisher::Common" do
  it "should convert has to/from string" do
    hash = {:a => 123, :b => "foo"}
    str = String.from_h(hash)
    stra = str.split(";")
    stra.include?("a=123").should be_true
    stra.include?("b=foo").should be_true
    hash = str.to_h
    hash["a"].should == "123"
    hash["b"].should == "foo"
  end
end
