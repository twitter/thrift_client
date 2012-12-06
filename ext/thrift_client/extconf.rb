require 'mkmf'

$CFLAGS = "-std=c99 -pedantic -O3 -fPIC -Wall -W -ggdb"
create_makefile('thrift_client/min_heap')
