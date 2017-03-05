#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'lib::DBI' ) || print "Bail out!\n";
}

diag( "Testing lib::DBI $lib::DBI::VERSION, Perl $], $^X" );
