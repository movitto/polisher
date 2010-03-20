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
    post '/gems/create', :name => 'gem-xml-test1', :source_id => 1
    post '/gems/create', :name => 'gem-xml-test2', :source_id => 1
    get '/gems.xml'
    last_response.should be_ok

    expect = "<gems>"
    ManagedGem.find(:all).each { |g| expect += "<id>#{g.id}</id><name>#{g.name}</name><source_id>#{g.source_id}</source_id>" }
    expect += "</gems>"
    last_response.body.gsub(/\s*/, '').should == expect.gsub(/\s*/, '') # ignore whitespace differences
  end

  it "should allow gem creations" do
    lambda do
      post '/gems/create', :name => 'create-gem-test', :source_id => 1
    end.should change(ManagedGem, :count).by(1)
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/gems"
  end

  it "should allow gem deletions" do
    post '/gems/create', :name => 'delete-gem-test', :source_id => 1
    gem_id = ManagedGem.find(:first, :conditions => ['name = ?', 'delete-gem-test']).id
    lambda do
      delete "/gems/destroy/#{gem_id}"
    end.should change(ManagedGem, :count).by(-1)
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/gems"
  end

  # run simulate gemcutter api firing process
  it "should successfully post-process an updated gem" do
      gem   = ManagedGem.create :name => 'foobar', :source_id => 1

      event = Event.create :managed_gem => gem, 
                           :process => "integration_test_handler1",
                           :version_qualifier => '>',
                           :gem_version => 1.2

      event = Event.create :managed_gem => gem, 
                           :process => "integration_test_handler2",
                           :version_qualifier => '<',
                           :gem_version => 1.1

      post '/gems/updated', :name => 'foobar', 
                            :version => '1.3', 
                            :gem_uri => 'http://gemcutter.org/gems/foobar-1.3.gem'

      $integration_test_handler_flags.include?(1).should == true
      $integration_test_handler_flags.include?(2).should == false
  end

  it "should respond to /sources" do
    get '/sources'
    last_response.should be_ok
  end

  it "shold allow source creations" do
    lambda do
      post '/sources/create', :name => 'create-source-test', :uri => 'http://example1.org'
    end.should change(Source, :count).by(1)
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/sources"
  end

  it "should get sources in xml format" do
    post '/sources/create', :name => 'source-xml-test1', :uri => 'http://foo.host'
    post '/sources/create', :name => 'source-xml-test2', :uri => 'http://bar.host'
    get '/sources.xml'
    last_response.should be_ok

    expect = "<sources>"
    Source.find(:all).each { |s| expect += "<id>#{s.id}</id><name>#{s.name}</name><uri>#{s.uri}</uri>" }
    expect += "</sources>"
    last_response.body.gsub(/\s*/, '').should == expect.gsub(/\s*/, '') # ignore whitespace differences
  end


  it "should allow source deletions" do
    post '/sources/create', :name => 'delete-source-test', :uri => 'http://example2.org'
    source_id = Source.find(:first, :conditions => ['name = ?', 'delete-source-test']).id
    lambda do
      delete "/sources/destroy/#{source_id}"
    end.should change(Source, :count).by(-1)
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/sources"
  end

  it "shold allow event creations" do
    gem = ManagedGem.create :name => "create-event-test-gem", :source_id => 1
    lambda do
      post '/events/create', :managed_gem_id => gem.id, 
                             :process => 'fooproc', 
                             :gem_version => '1.0',
                             :version_qualifier => ">",
                             :process_options => 'opts'
    end.should change(Event, :count).by(1)
    follow_redirect!
    last_response.should be_ok
    last_request.url.should == "http://example.org/gems"
  end

  it "should allow event deletions" do
    gem = ManagedGem.create :name => "delete-event-test-gem", :source_id => 1
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

def integration_test_handler1(gem)
  $integration_test_handler_flags << 1
end

def integration_test_handler2(gem)
  $integration_test_handler_flags << 2
end
