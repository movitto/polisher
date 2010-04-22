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

require 'active_record'

Dir[File.dirname(__FILE__) + '/models/*.rb'].each { |model| require model }

module Polisher
  module DB

    # Load db config from specified file / environment
    def self.load_config(file_path, env = 'development')
      YAML::load(File.open(file_path))[env.to_s]
    end

    # Connect to database specified in config
    def self.connect(config, logger)
      ActiveRecord::Base.logger = logger
      ActiveRecord::Base.establish_connection config
    end

    # Perform any outstanding db migrations
    def self.migrate(migrations_dir)
      ActiveRecord::Migration.verbose = true
      ActiveRecord::Migrator.migrate(migrations_dir)
    end

    # Perform a single polisher db rollback
    def self.rollback(migrations_dir)
      ActiveRecord::Migration.verbose = true
      ActiveRecord::Migrator.rollback(migrations_dir)
    end

    # Drop all tables in the db
    def self.drop_tables(migrations_dir)
      ActiveRecord::Migration.verbose = true
      ActiveRecord::Migrator.down(migrations_dir, 0)
    end

  end
end
