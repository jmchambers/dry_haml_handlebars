# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "dry_haml_handlebars/version"

Gem::Specification.new do |s|
  s.name        = "dry_haml_handlebars"
  s.version     = DryHamlHandlebars::VERSION
  s.authors     = ["Jonathan Chambers"]
  s.email       = ["j.chambers@gmx.net"]
  s.homepage    = "https://github.com/jmchambers/dry_haml_handlebars"
  s.summary     = "Write haml templates, use both server and clientside (via handlebars.js)"
  s.description = "Write haml views once, and then use them for both server and clientside rendering (using automagically precompiled handlebars templates)"

  s.rubyforge_project = "dry_haml_handlebars"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.add_dependency "rails",             ">= 3.2.0"
  s.add_dependency "therubyracer"
  s.add_dependency "haml-rails",        ">= 0.3.4"
  s.add_dependency "handlebars_assets", ">= 0.4.1"
  s.add_dependency "rabl",              ">= 0.6.2"
  s.add_dependency "gon",               ">= 2.2.2"
  
  s.license       = 'MIT'
  
end
