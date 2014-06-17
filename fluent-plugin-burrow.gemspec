# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "fluent-plugin-burrow"
  s.version     = "1.0"
  s.license     = "MIT"
  s.authors     = ["Tim Gunter"]
  s.email       = ["tim@vanillaforums.com"]
  s.homepage    = "https://github.com/vanilla/fluent-plugin-burrow"
  s.summary     = %q{Fluentd output filter plugin. Extract a single key (in formats Fluent can natively understand) from an event and re-emit a new event that replaces the entire original record with that key's values.}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rake"
  s.add_runtime_dependency "fluentd"
end