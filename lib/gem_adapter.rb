# Gem adapter, provides interface to many gem routines
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

module Polisher
module GemAdapter

   # Subscribe callback_url to gem updates from the specified source.
   def subscribe(source, callback_url, gem_api_key)
      raise ArgumentError, "must specify valid source, callback url, and api key" if source.nil? || callback_url.class != String || gem_api_key.class != String

      subscribe_path = '/api/v1/web_hooks'
      headers = { 'Authorization' => gem_api_key }
      data = "gem_name=#{source.name}&url=#{callback_url}"

      begin
        http = Net::HTTP.new(URI.parse(source.uri).host, 80)
        res = http.post(subscribe_path, data, headers)
        raise RuntimeError if res.class == Net::HTTPNotFound
      rescue Exception => e
        raise RuntimeError, "could not subscribe to gem #{source.name} at #{source.uri}#{subscribe_path}"
      end
   end
   module_function :subscribe

   # Determine if we are subscribed to gem specified by source with the specified gem_api_key
   def subscribed?(source, gem_api_key)
      raise ArgumentError, "must specify valid source and api key" if source.nil? || gem_api_key.class != String

      subscribe_path = '/api/v1/web_hooks.json'
      headers = { 'Authorization' => gem_api_key }

      begin
        http = Net::HTTP.new(URI.parse(source.uri).host, 80)
        res  = http.get(subscribe_path, headers).body
        raise RuntimeError if res.class == Net::HTTPNotFound
        res  = JSON.parse(res)
        return res.has_key?(source.name)

      rescue Exception => e
        raise RuntimeError, "could not connect to gem source at #{source.uri}#{subscribe_path}"
      end
   end
   module_function :subscribed?

   # Unsubscribe to updates to the gem specified by source w/  the specified callback_url and api_key
   def unsubscribe(source, callback_url, gem_api_key)
      return unless subscribed?(source, gem_api_key)
      raise ArgumentError, "must specify valid source, callback url, and api key" if source.nil? || callback_url.class != String || gem_api_key.class != String

      subscribe_path = "/api/v1/web_hooks/remove?gem_name=#{source.name}&url=#{callback_url}"
      headers = { 'Authorization' => gem_api_key }

      begin
        http = Net::HTTP.new(URI.parse(source.uri).host, 80)
        res = http.delete(subscribe_path, headers)
        raise RuntimeError if res.class == Net::HTTPNotFound
      rescue Exception => e
        raise RuntimeError, "could not delete gem #{source.name} via #{source.uri}#{subscribe_path}"
      end
   end
   module_function :unsubscribe

   # Return hash of gem attributes/values retreived from remote source
   def get_info(source)
     info = nil
     source_uri = URI.parse(source.uri).host
     get_path = "/api/v1/gems/#{source.name}.json"
     begin
       Net::HTTP.start(source_uri, 80) { |http|
          res = http.get(get_path).body
          raise RuntimeError if res.class == Net::HTTPNotFound
          info = JSON.parse(res)
       }
     rescue Exception => e
      raise RuntimeError, "could not get info for gem #{source.name} via #{source.uri}#{get_path}"
     end

     return info
   end
   module_function :get_info

end # module GemAdapter
end # module Polisher
