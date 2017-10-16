# -*- encoding: utf-8 -*-

VERSION = File.read("CHANGELOG")[/^\s*v([\d\w\.]+)(\.|\s|$)/, 1]

Gem::Specification.new do |s|
  s.name          = "thrift_client"
  s.version       = VERSION

  s.platform      = Gem::Platform::RUBY
  s.authors       = ["Evan Weaver", "Ryan King", "Jeff Hodges"]
  s.homepage      = "https://github.com/twitter/thrift_client"
  s.summary       = "A Thrift client wrapper that encapsulates some common failover behavior."
  s.license       = "Apache 2.0"

  s.files         = Dir["lib/**/*.rb"].to_a
  s.test_files    = Dir["test/**/*.rb"].to_a

  s.require_paths = ["lib"]

  s.add_dependency("thrift", ["~> 0.10.0"])

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rack'
  s.add_development_dependency 'thin'
end
