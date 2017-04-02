use Mojo::Base -strict;

use strict;
use utf8;
use Test::More;
use DBI;
use lib::DBI;

my $config;
BEGIN {
  use FindBin qw($Bin);
  $config = do "$Bin/config.pl";
}

plan skip_all => 'set env TEST_PG="DBI:Pg:dbname=<...>/<pg_user>/<passwd>" to enable this test' unless $ENV{TEST_PG};

my ($dbh, $lib);

if ($config->{connect}) {
  $dbh = DBI->connect(@{$config->{connect}});

  lib::DBI->config(dbh=>$dbh);

  $lib = lib::DBI->new(dbh=>$dbh);

}


isa_ok(lib::DBI->config("dbh"), 'DBI::db');
isa_ok($lib->config("dbh"), 'DBI::db');
ok(lib::DBI->config("dbh") eq $lib->config("dbh"), 'dbh ok');


done_testing();