# Copyright (C) 2010 Red Hat, Inc.
# Written by Mohammed Morsi <mmorsi@redhat.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.  A copy of the GNU General Public License is
# also available at http://www.gnu.org/copyleft/gpl.html.

require 'uri'
require 'net/http'
#require 'net/https'
require 'json'

# Adapts the gem(cutter) api to polisher
# http://gemcutter.org/pages/api_docs
class GemApiAdapter
   # retrieve gem information
   def self.gem_info(args = {})
      api_uri       = args[:api_uri]
      gem_name      = args[:gem_name]
      logger        = args[:logger]

      get_path = "/api/v1/gems/#{gem_name}.json"

      logger.info ">> getting gem #{gem_name} info from #{api_uri}#{get_path}" unless logger.nil?
      http = Net::HTTP.new(URI.parse(api_uri).host, 80)
      res  = http.get(get_path)
      logger.info ">> received #{res.body}"
      JSON.parse(res.body)
   end

   # use api endpoint/credentials to add subscription for specified gem / url
   def self.subscribe(args = {})
      api_uri       = args[:api_uri]
      api_key       = args[:api_key]
      gem_name      = args[:gem_name]
      callback_url  = args[:callback_url]
      logger        = args[:logger]

      subscribe_path = '/api/v1/web_hooks'

      http = Net::HTTP.new(URI.parse(api_uri).host, 80)
      data = "gem_name=#{gem_name}&url=#{callback_url}"
      headers = { 'Authorization' => api_key }
      logger.info ">> sending http request to #{URI.parse(api_uri).host}#{subscribe_path}; data:#{data}; headers:#{headers}"
      res = http.post(subscribe_path, data, headers)
      # FIXME handle res = #<Net::HTTPNotFound:0x7f1df8319e40> This gem could not be found
      logger.info ">> http response received #{res} #{res.body}"
   end

   # retrieve gem and save to file
   def self.get_gem(args = {})
        uri  = args[:uri]
        gemfile = args[:file]
        logger  = args[:logger]

        # handle redirects
        found = false
        until found  # FIXME should impose a max tries
          gem_uri = URI.parse(uri)
          http = Net::HTTP.new(gem_uri.host, 80)
          res =  http.get(gem_uri.path)
          if res.code == "200"
             File.open(gemfile, "wb") { |f| f.write res.body }
             found = true
          else
             uri = res.header['location']
          end
        end
   end

   # helper, convert gem uri to source uri
   def self.gem_to_source_uri(gem_uri)
      uri = URI.parse(gem_uri)
      return uri.scheme + "://" + uri.host
   end
end
