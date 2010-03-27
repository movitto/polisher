# polisher project Rakefile

require 'lib/common'
require 'db/connection'
require 'rake/rdoctask'
require 'spec/rake/spectask'
require 'rake/gempackagetask'

#task :default => :test

env = ENV['RACK_ENV']
env ||= 'development'

logger = Logger.new(STDOUT)

GEM_NAME='polisher'
PKG_VERSION='0.3'

namespace :db do
  desc "Migrate the database"
  task :migrate do
    Polisher::DB.connect Polisher::DB.load_config('./config/database.yml', env), logger
    Polisher::DB.migrate './db/migrations'
  end

  desc "Rollback the database"
  task :rollback do
    Polisher::DB.connect Polisher::DB.load_config('./config/database.yml', env), logger
    Polisher::DB.rollback './db/migrations'
  end

  desc "Drop all tables in the database"
  task :drop_tables do
    Polisher::DB.connect Polisher::DB.load_config('./config/database.yml', env), logger
    Polisher::DB.drop_tables './db/migrations'
  end
end

task 'test_env' do
  env = 'test'
  create_missing_polisher_dirs(:artifacts_dir => 'spec/artifacts', :db_data_dir => 'db/data', :log_dir => 'log')
end

desc "Run all specs"
Spec::Rake::SpecTask.new('spec' => ['test_env', 'db:drop_tables', 'db:migrate']) do |t|
  t.spec_files = FileList['spec/*_spec.rb']
end

Rake::RDocTask.new do |rd|
    rd.main = "README.rdoc"
    rd.rdoc_dir = "doc/site/api"
    rd.rdoc_files.include("README.rdoc", "polisher.rb", "db/**/*.rb", "lib/**/*.rb")
end

PKG_FILES = FileList['bin/*', 'config/*.yml', 'config.ru', 'COPYING', 
'db/**/*.rb', 'lib/**/*.rb', 'LICENSE', 'polisher.rb', 'public/**/*', 'Rakefile', 
'README.rdoc', 'spec/**/*.rb', 'TODO', 'views/**/*.haml']

DIST_FILES = FileList[
  "pkg/*.tgz", "pkg/*.gem"
]

SPEC = Gem::Specification.new do |s|
    s.name = GEM_NAME
    s.version = PKG_VERSION
    s.files = PKG_FILES

    s.required_ruby_version = '>= 1.8.1'
    s.required_rubygems_version = Gem::Requirement.new(">= 1.3.3")

    s.author = "Mohammed Morsi"
    s.email = "mmorsi@redhat.com"
    s.date = %q{2010-03-11}
    s.description = "Ruby gem polisher"
    s.summary = "Ruby gem polisher"
    s.homepage = "http://github.com/movitto/polisher"
end

Rake::GemPackageTask.new(SPEC) do |pkg|
    pkg.need_tar = true
    pkg.need_zip = true
end
