
require 'rubygems'
require 'echoe'

Echoe.new("thrift_client") do |p|
  p.author = ["Evan Weaver", "Ryan King", "Jeff Hodges"]
  p.project = "fauna"
  p.summary = "A Thrift client wrapper that encapsulates some common failover behavior."
  p.rubygems_version = ">= 0.8"
  p.dependencies = ['thrift >=0.7.0', 'thrift <0.9.0']
  p.ignore_pattern = /^(vendor\/thrift)/
  p.rdoc_pattern = /^(lib|bin|tasks|ext)|^README|^CHANGELOG|^TODO|^LICENSE|^COPYING$/
  p.spec_pattern = "spec/*_spec.rb"
end
