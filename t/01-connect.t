use Mojo::Base -strict;

use strict;
use utf8;
use Test::More;
use DBI;
use lib::DBI;

plan skip_all => 'set env TEST_PG="DBI:Pg:dbname=<...>/<pg_user>/<passwd>" to enable this test' unless $ENV{TEST_PG};

my @conn = split m|[/]|, $ENV{TEST_PG};
$conn[3] = {pg_enable_utf8 => 1,};

my $dbh = DBI->connect(@conn);

lib::DBI->config(dbh=>$dbh);

my $lib = lib::DBI->new(dbh=>$dbh);


isa_ok(lib::DBI->config("dbh"), 'DBI::db');
isa_ok($lib->config("dbh"), 'DBI::db');
ok(lib::DBI->config("dbh") eq $lib->config("dbh"), 'dbh ok');


done_testing();