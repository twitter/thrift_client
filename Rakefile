require 'rubygems'
require 'rake/testtask'
require 'rake/clean'

EXT = RbConfig::CONFIG['DLEXT']

# rule to build the extension: this says
# that the extension should be rebuilt
# after any change to the files in ext
file "lib/thrift_client/min_heap.#{EXT}" => Dir.glob("ext/thrift_client/*{.rb,.c}") do
  Dir.chdir("ext/thrift_client") do
    # this does essentially the same thing
    # as what RubyGems does
    ruby "extconf.rb"
    sh "make"
  end
  cp "ext/thrift_client/min_heap.#{EXT}", "lib/thrift_client"
end

# make the :test task depend on the shared
# object, so it will be built automatically
# before running the tests
task :test => "lib/thrift_client/min_heap.#{EXT}"

task :make => "lib/thrift_client/min_heap.#{EXT}"

# use 'rake clean' and 'rake clobber' to
# easily delete generated files
CLEAN.include("ext/**/*{.o,.log,.#{EXT}}")
CLEAN.include('ext/**/Makefile')
CLOBBER.include("lib/**/*.#{EXT}")

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

task :build do
  `gem build thrift_client.gemspec`
end

task :default => :test
