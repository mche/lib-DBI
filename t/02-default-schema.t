use Mojo::Base -strict;

use strict;
use utf8;
use Test::More;

#~ use DBI;

#~ use Foo;

my $config;
BEGIN {
  use FindBin qw($Bin);
  $config = do "$Bin/config.pl";
}

use lib::DBI $config->{connect} ? (
  connect=> $config->{connect},
  do => [qq'CREATE SCHEMA IF NOT EXISTS "$config->{default}{schema}"', qq'set search_path to "$config->{default}{schema}"', $config->{default}{do}],
  ) : ()
;

plan skip_all => 'set env TEST_PG="DBI:Pg:dbname=<...>/<pg_user>/<passwd>" to enable this test' unless $ENV{TEST_PG};

my $dbh = lib::DBI->config("dbh");

isa_ok($dbh, 'DBI::db');

is($dbh->selectrow_array("show search_path"), qq'"$config->{default}{schema}"', 'ok schema');

done_testing();