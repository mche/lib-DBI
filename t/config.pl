use utf8;
use strict;
use FindBin qw($Bin);

sub slurp {
  my $file = shift;
  open my $fh, "<", $file or die $!;
  local $/; # enable localized slurp mode
  my $content = <$fh>;
  close $fh;
  return $content;
}

{
  connect => do {
    my @conn = split m|[/]|, $ENV{TEST_PG}; # TEST_PG="DBI:Pg:dbname=test/guest"
    $conn[3] = {pg_enable_utf8 => 1,};
    $ENV{TEST_PG} ? \@conn : undef;
  },
  default=>{
    schema => "default lib::DBI test",
    do => slurp  "$Bin/default.sql",
    
  },
  custom=>{
    schema => "custom lib::DBI test",
    do => slurp  "$Bin/custom.sql",
    
  },
};