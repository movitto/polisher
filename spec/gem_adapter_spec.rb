# ruby gem polisher gem adapter spec
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

require 'uri'
require 'json'
require 'net/http'

require File.dirname(__FILE__) + '/spec_helper'

describe "Polisher::GemAdapter" do
  it "should successfully subscribe/unsubscribe to updates" do
     gem = Source.new :name => "polisher", :source_type => "gem", 
                      :uri => "http://rubygems.org/downloads/polisher-0.3.gem"

     Polisher::GemAdapter.subscribe(gem,  
                                    "http://projects.morsi.org/polisher/demo/gems/released/1", 
                                    POLISHER_CONFIG["gem_api_key"])
     Polisher::GemAdapter.subscribed?(gem, POLISHER_CONFIG["gem_api_key"]).should == true
     Polisher::GemAdapter.unsubscribe(gem,  
                                    "http://projects.morsi.org/polisher/demo/gems/released/1", 
                                    POLISHER_CONFIG["gem_api_key"])
     Polisher::GemAdapter.subscribed?(gem, POLISHER_CONFIG["gem_api_key"]).should == false
  end

  it "should raise error if subscribe source, callback_url, or api_key is invalid" do
     lambda { 
       Polisher::GemAdapter.subscribe(nil, 
                                      "http://projects.morsi.org/polisher/demo/gems/released/1", 
                                      POLISHER_CONFIG['gem_api_key'])
     }.should raise_error(ArgumentError)

     gem = Source.new :name => "polisher", :source_type => "gem", 
                      :uri => "http://rubygems.org/downloads/polisher-0.3.gem"
     lambda { 
       Polisher::GemAdapter.subscribe(gem, 42, POLISHER_CONFIG['gem_api_key']) 
     }.should raise_error(ArgumentError)

     lambda {
       Polisher::GemAdapter.subscribe(gem, 
                                      "http://projects.morsi.org/polisher/demo/gems/released/1", 
                                      nil)
     }.should raise_error(ArgumentError)
  end

  it "should raise error if subscription target is invalid" do
    gem = Source.new :name => "polisher", :source_type => "gem", 
                     :uri => "http://non.existant/downloads/polisher-0.3.gem"
    lambda {
      Polisher::GemAdapter.subscribe(gem,  
                                     "http://projects.morsi.org/polisher/demo/gems/released/1", 
                                     POLISHER_CONFIG["gem_api_key"])
    }.should raise_error(RuntimeError)

    gem = Source.new :name => "polisher", :source_type => "gem", 
                     :uri => "http://morsi.org/downloads/polisher-0.3.gem"
    lambda {
      Polisher::GemAdapter.subscribe(gem,  
                                     "http://projects.morsi.org/polisher/demo/gems/released/1", 
                                     POLISHER_CONFIG["gem_api_key"])
    }.should raise_error(RuntimeError)
  end

  it "should successfully get remote gem info" do
     gem = Source.new :name => "polisher", :source_type => "gem", 
                      :uri => "http://rubygems.org/downloads/polisher-0.3.gem"
     info = Polisher::GemAdapter.get_info(gem)
     info["name"].should == "polisher"
  end

  it "should raise error if get info target is invalid" do
    gem = Source.new :name => "polisher", :source_type => "gem", 
                     :uri => "http://invalid.uri/downloads/polisher-0.3.gem"
     lambda {
       Polisher::GemAdapter.get_info(gem)
     }.should raise_error(RuntimeError)
  end

end
