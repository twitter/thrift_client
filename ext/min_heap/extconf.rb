require 'mkmf'

$CFLAGS = "-std=c99 -pedantic -O3 -fPIC -Wall -W -ggdb"
create_makefile('min_heap/min_heap')
