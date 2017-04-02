use Mojo::Base -strict;

use strict;
use utf8;
use Test::More;
use DBI;

my $config;
BEGIN {
  use FindBin qw($Bin);
  $config = do "$Bin/config.pl";

}

use lib::DBI $config->{connect} ? (
  dbh=> DBI->connect(@{$config->{connect}}),
  do => [qq'DROP SCHEMA IF EXISTS "$config->{default}{schema}" CASCADE', qq'DROP SCHEMA IF EXISTS "$config->{custom}{schema}" CASCADE',],
  ) : ()
;

plan skip_all => 'set env TEST_PG="DBI:Pg:dbname=<...>/<pg_user>/<passwd>" to enable this test'
  and done_testing()
  and exit
  unless $ENV{TEST_PG};

my $dbh = lib::DBI->config("dbh");

isa_ok($dbh, 'DBI::db');

done_testing();