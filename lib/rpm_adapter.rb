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

# use gem2rpm to create rpm from gem
require 'gem2rpm'

# Adapts rpm subsystem to polisher
class RpmAdapter
  # build rpm from specified args
  def self.build(args = {})
    gem     = args[:gem]
    logger   = args[:logger]
    outfile = "../tmp/rpms/#{gem.name}-#{gem.version}.spec." + Time.now.strftime("%y%m%d%H%M%S")
    outfh   = File.open(outfile, "wb")

    # get gem / write to file
    gemfile = "../tmp/gems/#{gem.name}-#{gem.version}.gem"
    logger.info ">> retreive gem from #{gem.uri} and writing to #{Dir.pwd}/#{gemfile}"
    GemApiAdapter.get_gem :uri => gem.uri, :file => gemfile, :logger => logger

    logger.info ">> generating rpm spec #{outfile} from gemfile #{gemfile}" unless logger.nil?
    Gem2Rpm::convert gemfile, Gem2Rpm::TEMPLATE, outfh
  end
end
