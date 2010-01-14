# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{polisher}
  s.version = "0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.3")
  s.author = "Mohammed Morsi"
  s.date = %q{2010-01-13}
  s.description = %q{ruby gem polisher / post-publishing-processor}
  s.summary     = %q{polisher provides a rails based interface for a user to 
                     track packages posted to any number of gem repositories 
                     and automatically invoke callback handlers upon package events}
  s.email = %q{mmorsi@redhat.com}
  s.extra_rdoc_files = [ "README", ]
  s.files = Dir.glob("{app/controllers,app/helpers,app/models,app/views,config,db,lib,public,script,tmp}/**/*") 
  s.has_rdoc = true
  s.homepage = %q{http://github.com/movitto/polisher}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]

  s.add_dependency 'rails', ">= 2.3.2"
end
