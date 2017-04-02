use Mojo::Base -strict;

use strict;
use utf8;
use Test::More;
use DBI;
#~ use Mojo::Loader qw(load_class);

my $config;
BEGIN {
  use FindBin qw($Bin);
  $config = do "$Bin/config.pl";
}

use lib::DBI $config->{connect} ? (
  dbh=> DBI->connect(@{$config->{connect}}),
  do => [qq'CREATE SCHEMA IF NOT EXISTS "$config->{default}{schema}"', qq'set search_path to "$config->{default}{schema}"', $config->{default}{do}],
  ) : ()
;

plan skip_all => 'set env TEST_PG="DBI:Pg:dbname=<...>/<pg_user>/<passwd>" to enable this test'
  and done_testing()
  and exit
  unless $ENV{TEST_PG};

use Foo2;
#~ use Foo4;



#~ lib::DBI->module('Foo2', compile=>1, append=>"123;", debug=>1,);
#~ warn lib::DBI->module('Foo2', compile=>1, append=>"0x01;", debug=>0,);
my $foo2 = Foo2->new;
isa_ok($foo2, 'Foo2', 'class Foo2');
is($foo2->bar, 'Foo2 bar sub', 'right method');

#~ my $e = load_class  "Foo::Not";

#~ eval "require Foo::Not;";
#~ like($@, qr/\@INC/, 'right not found');
#~ warn lib::DBI->module('Foo::Not', compile=>0, append=>"123;", debug=>1,) || 'Not found';

#~ my $foo3 = lib::DBI->module('Foo3', debug=>1, compile=>1)->new;
#~ warn $foo3;
#~ warn lib::DBI->module('Foo3', compile=>1, append=>"0x01;", debug=>0,);
require Foo3;
my $foo3 = Foo3->new();
isa_ok($foo3, 'Foo3', 'class Foo3');
is($foo3->bar, 'Foo3 bar sub', 'right method');

warn lib::DBI->module('Foo5.js', compile=>0, append=>"5;", debug=>1,);


warn lib::DBI->module('Foo6', compile=>0, append=>";", debug=>1,);

warn lib::DBI->module('Foo::Not', compile=>0, append000=>";", debug=>1,) || 'not Foo';

warn lib::DBI->module('Bar::Not', compile=>0, append000=>";", debug=>1,) || 'not Bar';
warn lib::DBI->module('Bar::Not', compile=>0, append000=>";", debug=>1,) || 'not Bar';

warn 123;

my $dbh = lib::DBI->config("dbh");
isa_ok($dbh, 'DBI::db', 'class DBI');

is($dbh->selectrow_array("show search_path"), qq'"$config->{default}{schema}"', 'ok schema');

done_testing();