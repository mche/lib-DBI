use Mojo::Base -strict;

use strict;
use utf8;
use Test::More;
#~ use DBI;
use lib::DBI connect=>[split m|[/]|, $ENV{TEST_PG}, {pg_enable_utf8 => 1,}];

plan skip_all => 'set env TEST_PG="DBI:Pg:dbname=<...>/<pg_user>/<passwd>" to enable this test' unless $ENV{TEST_PG};


isa_ok(lib::DBI->config("dbh"), 'DBI::db');

done_testing();