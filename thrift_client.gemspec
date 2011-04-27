# -*- encoding: utf-8 -*-
require File.expand_path('../lib/thrift_client/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name = 'thrift_client'
  gem.version = '0.6.1'
  gem.add_runtime_dependency 'thrift', '~> 0.6.0'
  gem.add_development_dependency 'rake', '~> 0.8'
  gem.add_development_dependency 'mongrel', '~> 1.1'
  gem.required_rubygems_version = Gem::Requirement.new(">= 1.2.0") if gem.respond_to? :required_rubygems_version=
  gem.authors = ["Evan Weaver", "Ryan King", "Jeff Hodges"]
  gem.description = "A Thrift client wrapper that encapsulates some common failover behavior."
  gem.email = ["evan@cloudbur.st", "ryan@theryanking.com", "jeff@somethingsimilar.com"]
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files = `git ls-files`.split("\n")
  gem.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.homepage = 'https://github.com/fauna/thrift_client'
  gem.require_paths = ["lib"]
  gem.summary = gem.description
end
