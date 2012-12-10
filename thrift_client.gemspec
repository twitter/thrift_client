# -*- encoding: utf-8 -*-

VERSION = File.read("CHANGELOG")[/^\s*v([\d\w\.]+)(\.|\s|$)/, 1]

Gem::Specification.new do |s|
  s.name          = "thrift_client"
  s.version       = VERSION

  s.platform      = Gem::Platform::RUBY
  s.authors       = ["Evan Weaver", "Ryan King", "Jeff Hodges"]
  s.homepage      = "https://github.com/twitter/thrift_client"
  s.summary       = "A Thrift client wrapper that encapsulates some common failover behavior."

  s.files         = Dir.glob('lib/**/*.rb') +
                    Dir.glob('ext/**/*.{c,h,rb}')
  s.test_files    = Dir["test/**/*.rb"].to_a
  s.extensions    = ['ext/thrift_client/extconf.rb']

  s.require_paths = ["lib"]

  s.add_dependency("thrift", ["~> 0.8.0"])

  s.add_development_dependency 'rake'
  s.add_development_dependency 'mongrel', '1.2.0.pre2'
end
