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
require 'curl' # requires 'curb' package

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
      raise ArgumentError, "must specify valid callback url and api key" unless callback_url.class == String && api_key.class == String

      subscribe_path = '/api/v1/web_hooks'
      headers = { 'Authorization' => api_key }
      data = "gem_name=#{name}&url=#{callback_url}"

      begin
        http = Net::HTTP.new(URI.parse(gem_source.uri).host, 80)
        res = http.post(subscribe_path, data, headers)
        raise RuntimeError if res.class == Net::HTTPNotFound
      rescue Exception => e
        raise RuntimeError, "could not subscribe to gem #{name} at #{gem_source.uri}#{subscribe_path}"
      end
   end

   # determine if we are subscribed to gem
   def subscribed?
      api_key = POLISHER_CONFIG["gem_api_key"]
      raise ArgumentError, "must specify valid api key" unless api_key.class == String

      subscribe_path = '/api/v1/web_hooks.json'
      headers = { 'Authorization' => api_key }

      begin
        http = Net::HTTP.new(URI.parse(gem_source.uri).host, 80)
        res  = http.get(subscribe_path, headers).body
        raise RuntimeError if res.class == Net::HTTPNotFound
        res  = JSON.parse(res)
        return res.has_key?(name)

      rescue Exception => e
        raise RuntimeError, "could not connect to gem source at #{gem_source.uri}#{subscribe_path}"
      end
   end

   # unsubscribe to updates to this gem from associated gem source
   def unsubscribe(args = {})
      return unless subscribed?
      callback_url = args[:callback_url]
      api_key = POLISHER_CONFIG["gem_api_key"]
      raise ArgumentError, "must specify valid callback url and api key" unless callback_url.class == String && api_key.class == String

      subscribe_path = "/api/v1/web_hooks/remove?gem_name=#{name}&url=#{callback_url}"
      headers = { 'Authorization' => api_key }

      begin
        http = Net::HTTP.new(URI.parse(gem_source.uri).host, 80)
        res = http.delete(subscribe_path, headers)
        raise RuntimeError if res.class == Net::HTTPNotFound
      rescue Exception => e
        raise RuntimeError, "could not delete gem #{name} via #{gem_source.uri}#{subscribe_path}"
      end
   end

   # return hash of gem attributes/values retreived from remote source
   def get_info
     info = nil
     source_uri = URI.parse(gem_source.uri).host
     get_path = "/api/v1/gems/#{name}.json"
     begin
       Net::HTTP.start(source_uri, 80) { |http|
          res = http.get(get_path).body
          raise RuntimeError if res.class == Net::HTTPNotFound
          info = JSON.parse(res)
       }
     rescue Exception => e
      raise RuntimeError, "could not get info for gem #{name} via #{source_uri}#{get_path}"
     end

     return info
   end

   def download_to(args = {})
     path = args.has_key?(:path) ? args[:path] : nil
     dir  = args.has_key?(:dir)  ? args[:dir]  : nil
     version = args.has_key?(:version) ? args[:version]  : nil
     gem_uri = nil

     if version.nil?
       info = get_info
       gem_uri = info["gem_uri"]
       version = info["version"]
     else
       gem_uri = source.uri + "/gems/#{name}-#{version}.gem"
     end

     begin
       path = dir + "/#{name}-#{version}.gem" if path.nil?
       dir  = File.dirname(path)
       raise ArgumentError unless File.writable?(dir)

       curl = Curl::Easy.new(gem_uri)
       curl.follow_location = true # follow redirects
       curl.perform
       File.write path, curl.body_str

     rescue Exception => e
       raise RuntimeError, "could not download gem from #{gem_uri} to #{path}"
     end

     return path
   end
end
