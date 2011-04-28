# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{thrift_client}
  s.version = "0.6.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0.8") if s.respond_to? :required_rubygems_version=
  s.authors = ["Evan Weaver, Ryan King, Jeff Hodges"]
  s.date = %q{2011-04-28}
  s.description = %q{A Thrift client wrapper that encapsulates some common failover behavior.}
  s.email = %q{}
  s.extra_rdoc_files = ["CHANGELOG", "LICENSE", "README.rdoc", "lib/thrift_client.rb", "lib/thrift_client/abstract_thrift_client.rb", "lib/thrift_client/connection.rb", "lib/thrift_client/connection/base.rb", "lib/thrift_client/connection/factory.rb", "lib/thrift_client/connection/http.rb", "lib/thrift_client/connection/socket.rb", "lib/thrift_client/event_machine.rb", "lib/thrift_client/simple.rb", "lib/thrift_client/thrift.rb"]
  s.files = ["CHANGELOG", "LICENSE", "Manifest", "README.rdoc", "Rakefile", "lib/thrift_client.rb", "lib/thrift_client/abstract_thrift_client.rb", "lib/thrift_client/connection.rb", "lib/thrift_client/connection/base.rb", "lib/thrift_client/connection/factory.rb", "lib/thrift_client/connection/http.rb", "lib/thrift_client/connection/socket.rb", "lib/thrift_client/event_machine.rb", "lib/thrift_client/simple.rb", "lib/thrift_client/thrift.rb", "test/greeter/greeter.rb", "test/greeter/greeter.thrift", "test/greeter/server.rb", "test/multiple_working_servers_test.rb", "test/simple_test.rb", "test/test_helper.rb", "test/thrift_client_http_test.rb", "test/thrift_client_test.rb", "thrift_client.gemspec"]
  s.homepage = %q{http://fauna.github.com/fauna/thrift_client/}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Thrift_client", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{fauna}
  s.rubygems_version = %q{1.7.2}
  s.summary = %q{A Thrift client wrapper that encapsulates some common failover behavior.}
  s.test_files = ["test/multiple_working_servers_test.rb", "test/simple_test.rb", "test/test_helper.rb", "test/thrift_client_http_test.rb", "test/thrift_client_test.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<thrift>, ["~> 0.6.0"])
    else
      s.add_dependency(%q<thrift>, ["~> 0.6.0"])
    end
  else
    s.add_dependency(%q<thrift>, ["~> 0.6.0"])
  end
end
