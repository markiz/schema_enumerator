# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "schema_enumerator/version"

Gem::Specification.new do |s|
  s.name        = "schema_enumerator"
  s.version     = SchemaEnumerator::VERSION
  s.authors     = ["Mark Abramov"]
  s.email       = ["markizko@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Enumerates and diffs table schemas.}
  s.description = %q{Enumerates and diffs table schemas.
Also generates migrations using these diffs}

  s.rubyforge_project = nil

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec", "~> 2"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "pg"
  s.add_development_dependency "mysql2"
  s.add_runtime_dependency "sequel", ">= 3"
  s.add_runtime_dependency "diffy"
end
