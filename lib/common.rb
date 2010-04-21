# ruby gem polisher common routines
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

# read entire file into string
def File.read_all(path)
  File.open(path, 'rb') {|file| return file.read }
end

# write contents of file from string
def File.write(path, str)
  File.open(path, 'wb') {|file| file.write str }
end

# create any missing directories
def create_missing_polisher_dirs(args = {})
  artifacts_dir = args[:artifacts_dir]
  db_data_dir   = args[:db_data_dir]
  log_dir       = args[:log_dir]

  [artifacts_dir + '/repos',
   artifacts_dir + '/SOURCES', 
   artifacts_dir + '/SPECS', 
   artifacts_dir + '/templates', 
   log_dir, db_data_dir].each { |dir|
     FileUtils.mkdir_p(dir) unless File.directory? dir
   }
end

class String
  
  # Parse/split string around element delimiters (;) and 
  # key/value delimiters (=) and convert to hash.
  def to_h
    ret = {}
    split(';').each { |p| u = p.split('='); ret[u[0]] = u[1] }
    ret
  end

  # Convert hash into string
  def self.from_h(hash)
    hash.keys.collect { |k| k.to_s + "=" + hash[k].to_s }.join(";")
  end

end
