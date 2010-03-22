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

# Gem representation in polisher, associated w/ rubygem being
# managed, used to track updates and invoke handlers
class ManagedGem < ActiveRecord::Base
   belongs_to :gem_source
   has_many :events

   alias :source  :gem_source
   alias :source= :gem_source=

   validates_presence_of :name, :gem_source_id
   validates_uniqueness_of :name, :scope => :gem_source_id

   # TODO add validation to verify gem can be found in the associated gem source

   # helper, extract source uri from specified gem uri
   def self.uri_to_source_uri(gem_uri)
      uri = URI.parse(gem_uri)
      return uri.scheme + "://" + uri.host
   end

   # subscribe to updates to this gem from the associated gem source
   def subscribe(args = {})
      callback_url = args[:callback_url]
      api_key = POLISHER_CONFIG["gem_api_key"]

      subscribe_path = '/api/v1/web_hooks'
      headers = { 'Authorization' => api_key }
      data = "gem_name=#{name}&url=#{callback_url}"

      http = Net::HTTP.new(URI.parse(gem_source.uri).host, 80) 
      res = http.post(subscribe_path, data, headers)
      # TODO handle res = #<Net::HTTPNotFound:0x7f1df8319e40> This gem could not be found
   end

   # determine if we are subscribed to gem
   def subscribed?
      api_key = POLISHER_CONFIG["gem_api_key"]

      subscribe_path = '/api/v1/web_hooks.json'
      headers = { 'Authorization' => api_key }

      http = Net::HTTP.new(URI.parse(gem_source.uri).host, 80) 
      res  = http.get(subscribe_path, headers).body
      res  = JSON.parse(res)
      return res.has_key?(name)
   end

   # unsubscribe to updates to this gem from associated gem source
   def unsubscribe(args = {})
      return unless subscribed?
      callback_url = args[:callback_url]
      api_key = POLISHER_CONFIG["gem_api_key"]

      subscribe_path = "/api/v1/web_hooks/remove?gem_name=#{name}&url=#{callback_url}"
      headers = { 'Authorization' => api_key }

      http = Net::HTTP.new(URI.parse(gem_source.uri).host, 80) 
      res = http.delete(subscribe_path, headers)
   end

   # return hash of gem attributes/values retreived from remote source
   def get_info
       info = nil
       source_uri = URI.parse(gem_source.uri).host
       get_path = "/api/v1/gems/#{name}.json"
       Net::HTTP.start(source_uri, 80) { |http|
          info = JSON.parse(http.get(get_path).body)
       }
       return info
   end

   def download_to(args = {})
     path = args.has_key?(:path) ? args[:path] : nil
     dir  = args.has_key?(:dir)  ? args[:dir]  : nil
     version = args.has_key?(:version) ? args[:version]  : nil

     info = get_info
     gem_uri = info["gem_uri"]
     version = info["version"] if version.nil?
     path = dir + "/#{name}-#{version}.gem" if path.nil?

     # handle redirects
     found = false
     until found  # TODO should impose a max tries
       uri = URI.parse(gem_uri)
       http = Net::HTTP.new(uri.host, 80) 
       res =  http.get(uri.path)
       if res.code == "200"
          File.write path, res.body
          found = true
       else
          gem_uri = res.header['location']
       end 
     end 

     return path
   end
end
