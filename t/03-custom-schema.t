use Mojo::Base -strict;

use strict;
use utf8;
use Test::More;
use DBI;

#~ use Foo;

my $config;
BEGIN {
  use FindBin qw($Bin);
  $config = do "$Bin/config.pl";
}

use lib::DBI $config->{connect} ? (
  dbh=> DBI->connect(@{$config->{connect}}),
  do => [qq'CREATE SCHEMA IF NOT EXISTS "$config->{custom}{schema}"', qq'set search_path to "$config->{custom}{schema}"', $config->{custom}{do}],
  ) : ()
;

plan skip_all => 'set env TEST_PG="DBI:Pg:dbname=<...>/<pg_user>/<passwd>" to enable this test'
  and done_testing()
  and exit
  unless $ENV{TEST_PG};

my $dbh = lib::DBI->config("dbh");

isa_ok($dbh, 'DBI::db');

is($dbh->selectrow_array("show search_path"), qq'"$config->{custom}{schema}"', 'ok scheme');

done_testing();