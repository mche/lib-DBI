use Mojo::Base -strict;

use Test::More;
use DBI;
use lib::DBI;

plan skip_all => 'set env TEST_PG="DBI:Pg:dbname=<...>/<pg_user>/<passwd>" to enable this test' unless $ENV{TEST_PG};

my $dbh = DBI->connect(split m|[/]|, $ENV{TEST_PG});

lib::DBI->config(dbh=>$dbh);

my $lib = lib::DBI->new(dbh=>$dbh);

warn lib::DBI->config("dbh");
warn $lib->config("dbh");

isa_ok(lib::DBI->config("dbh"), 'DBI');
isa_ok($lib->config("dbh"), 'DBI');
ok(lib::DBI->config("dbh") eq $lib->config("dbh"), 'dbh ok');


done_testing();