package lib::DBI;

use 5.010;
use strict;
use utf8;
#~ use warnings FATAL => 'all';
use Carp qw(croak carp);

my %CACHE= ();# cache of loaded modules & subs

my %CONFIG = (## global default options
  dbh => undef,
  cols_name => {
    module_name =>"name",
    module_id =>"id",
    sub_name => "name",
    sub_id => "id",
    sub_code => "code",
  },
  #~ prepare=>'cached',# 
  compile => 1, # run time only for ->module(...)
  #~ type=> 'perl',
  debug => $ENV{DEBUG_LIB_DBI} // 0,
  cache=>\%CACHE, # ???
  module_sql => <<END_SQL, # SQL or DBI statement for extract rows/blocks of module
select s.*
from 
  modules m
  join subs s on s.module_id=m.id
where
  ( m.name=? or m.id=? )
  and (m.disabled is null or m.disabled = false)
  and (s.disabled is null or s.disabled = false)
  and (s.autoload is null or s.autoload = false)
order by s."order"
END_SQL
  module_bind_order => [qw(module_name module_id )],
  sub_sql => <<END_SQL, # SQL or DBI statement for extract row of anonimous sub
select s.*
from modules m
  join subs s on s.module_id=m.id
where
  ((( m.name=? or m.id=? ) and s.name=?) or s.id=?)
  and (m.disabled is null or m.disabled = false)
  and (s.disabled is null or s.disabled = false)
order by s."order"
END_SQL
  sub_bind_order => [qw(module_name module_id sub_name sub_id)],

);

BEGIN {
  push @INC, sub {# диспетчер
    return undef;
    my $self = shift;# эта функция CODE(0xf4d728) вроде не нужна
    my $mod = shift;#Имя
    $mod =~ s|/+|::|g;
    $mod =~ s|\.pm$||g;
    my $content = module_content($mod, %CONFIG, compile=>0, debug => 1,)
      or return undef;
    open my $fh, '<', \$content or die "Cant open: $!";
    return $fh;
  };
}

sub module_content {# text module extract
  my $mod = shift; # Module<id> or alias or name
  my %arg = @_;
  my $dbh = $arg{dbh}
    or return;
  
  #~ if (!$arg{module_name} && $mod && $arg{type} eq 'perl') {
    #~ $mod =~ s|/+|::|g;
    #~ $mod =~ s|\.pm$||g;
  #~ }
  $arg{module_name} ||= $mod || '';
  #~ $arg{id} //= ($mod =~ /^Module_id_(\d+)$/i)[0]; # Module43252
  $arg{module_id} //= 0;
  
  croak "Module undefined"
    unless $arg{module_name} || $arg{module_id};
  
  my $cache = $arg{cache}{"module name $arg{module_name}"} || $arg{cache}{"module id $arg{module_id}"}
    if $arg{cache};
  
  my $rows = $cache->{_rows}# строки модуля из кэша
    if  $cache;
  
  unless ($rows) {# не исп кэш или нет модуля в кэше
  
    my $sth = $dbh->prepare_cached($arg{module_sql})
    #~ $arg{prepare} eq 'cached'  ?
      #~ $dbh->prepare_cached($arg{module_sql})
      #~ : $dbh->prepare($arg{module_sql})
      if $arg{module_sql};
    
    my @bind = @arg{ @{$arg{module_bind_order}} };
    $rows = $dbh->selectall_arrayref($sth, {Slice=>{},}, @bind);
    $arg{debug} ? carp "Query content of the module [$arg{module_name}#$arg{module_id}] returns empty recordset (not found)" : 1
      and return
      unless @$rows;
    
    if ($arg{cache}) {
      $arg{cache}{"module name $arg{module_name}"}{_rows} = $rows
        if $arg{module_name};
      
      $arg{cache}{"module id $arg{module_id}"}{_rows} = $rows
        if $arg{module_id};
    }
  
  } 
  
  return join $arg{join} // "\n\n", map {$_->{$arg{cols_name}{sub_code}};} @$rows;
  
};


sub new {
  return bless { config => {%CONFIG, @_}, };
}


sub config {
  my ($self, $pkg) = ref $_[0] ? (shift, undef) : (undef, shift);
  my $config = $self ? $self->{config} : \%CONFIG;

  return $config
    unless @_;
  
  return $config->{shift()}
    if @_ == 1;
    
  my %arg = @_;
  @$config{ keys %arg } = values %arg;
  return $self || $pkg;
}

sub module {
  my ($self, $pkg) = ref $_[0] ? (shift, undef) : (undef, shift);
  my $mod = shift;
  my %arg = $self ? (%{$self->config()}, @_) : (%CONFIG, @_);
  
  my $content = module_content($mod, %arg)
      #~ or ($arg{debug} ? carp "Нет содержимого модуля [$mod]" : 1)
    or return undef;
  
  return $content
    unless $arg{compile};
  
  eval $content;
  if ($@) {
    croak "Fatal compile module [$mod]: $@";
  } elsif ($arg{debug}) {
    carp "Success compile module [$mod]\n";
  }

  return $mod;
}

sub sub {
  my ($self, $pkg) = ref $_[0] ? (shift, undef) : (undef, shift);
  my $mod_sub = shift; # Foo::bar  | Foo->bar
  my %arg = $self ? (%{$self->config()}, @_) : (%CONFIG, @_);
  
  my ($mod, $sub) = ref($mod_sub) eq 'ARRAY'
    ? @$mod_sub
    : do {
      $mod_sub =~ s/(?:->|::)([\wа-я]+)$//i;
      ($mod_sub, $1);
    }
    if $mod_sub;
  
  $arg{module_name} ||= $mod || '';
  $arg{sub_name} ||= $sub || '';
  $arg{module_id} //= ($mod =~ /^(\d+)$/i)[0] // 0; # Module432524
  $arg{sub_id} //= ($sub =~ /^(\d+)$/i)[0] // 0;
  
  croak "Нет имени модуля"
    unless $arg{module_name} || $arg{sub_id};
  
  croak "Нет имени subroutine"
    unless $arg{sub_name} || $arg{sub_id};
  
  my $cache_sub = $arg{cache}{"sub $arg{module_id}->$arg{sub_name}"}
    || $arg{cache}{"sub $arg{module_name}->$arg{sub_name}"}
    || $arg{cache}{"sub $arg{sub_id}"}
    if $arg{cache};
  
  if ($cache_sub) {
    return $cache_sub
      unless $arg{compile};

    return _eval_sub $cache_sub, \%arg
      unless $cache_sub->{_coderef};
    
    return $cache_sub->{_coderef};
  }

  # try to select and eval code
  my $dbh = $arg{dbh}
    or carp "Нет dbh соединения"
    and return;
  #~ $arg{select} ||= $Config{subs}{select}
    #~ or carp "[lib::DBI::subs] Нет select опции"
    #~ and return;
  my $sth = $dbh->prepare_cached($arg{sub_sql})
  #~ $arg{prepare} eq 'cached'
    #~ ? $dbh->prepare_cached($arg{sub_sql})
    #~ : $dbh->prepare($arg{sub_sql})
    if $arg{sub_sql};
  
  my @bind = @arg{ @{$arg{sub_bind_order}} };
  my $r = $dbh->selectrow_hashref($sth, undef, @bind)
    or $arg{debug} ? carp "Query content of the sub [$arg{module_name}::$arg{sub_name}#$arg{sub_id}] returns empty recordset" : 1
    and return;
  
  $arg{sub_name} ||= $r->{$arg{cols_name}{sub_name}}
    if $arg{cols_name}{sub_name};
    
  $arg{sub_id} ||= $r->{$arg{cols_name}{sub_id}}
    if $arg{cols_name}{sub_id};
  
  if ($arg{cache}) {
    $arg{cache}{"sub $arg{module_id}->$arg{sub_name}"} = $r
      if $arg{module_id} && $arg{sub_name};
      
    $arg{cache}{"sub $arg{module_name}->$arg{sub_name}"} = $r
      if $arg{module_name} && $arg{sub_name};
      
    $arg{cache}{"sub $arg{sub_id}"} = $r
      if $arg{sub_id};
    
  }
  
  return $r
    unless $arg{compile};
  
  return _eval_sub $r, \%arg;
}

sub _eval_sub {
  my ($r, $arg) = @_; # selected || cached row{} of sub
  my $code = $r->{$arg->{cols_name}{sub_code}};
  #~ $code =~ s|^\s*sub\s+{\s*|sub {\nmy \$self = \$r;\n|;
  my $eval = eval $code;
  if ($@) {
      croak "Fatal compile sub $arg->{module_name}::$arg->{sub_name}#$arg->{sub_id}: $@";
  } elsif ($arg->{debug}) {
      carp "Success compile sub $arg->{module_name}::$arg->{sub_name}#$arg->{sub_id}";
  }
  if (ref($eval) eq 'CODE') {
      $r->{_coderef} = $eval;
  }
  return $eval;
    
}


sub import { # это разбор аргументов после строк use lib::DBI
    my $pkg = shift;# is eq __PACKAGE__
    #~ warn "$pkg import";
    my $arg = ref $_[0] eq 'HASH' ? shift : {@_};
    $pkg->config(%$arg)
      if scalar keys %$arg;
    if (my $connect = $pkg->config('connect')) {
      require DBI;
      $pkg->config(dbh => DBI->connect(@$connect));
    }
    if (my $do = $pkg->config('do')) {
      
      $pkg->config('dbh')->do($_)
        for ref $do eq 'ARRAY' ? @$do : ($do);
    }
}

our $VERSION = '0.02';

=encoding utf8

Доброго всем! Доброго здоровья! Доброго духа!

=head1 lib::DBI

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 VERSION

Version 0.02

=head1 NAME

lib::DBI - Compile time and run time packages/modules and subs source code texts from DBI handle by querying SQL.

=head1 DESCRIPTION

Pragma lib::DBI push @INC, sub {...} once and this dispatcher will extracts Perl modules from the DBI sources at the compile time.

For run time there are class and object methods L</module> and L</sub> which also can compile sources of modules and subs.

=head1 SYNOPSIS

=head2 Compile time

  # PostgreSQL DBD example
  use lib::DBI connect => ['DBI:Pg:dbname=test', 'postgres', undef, {pg_enable_utf8 => 1,...}], ...;
  use My::Foo::Module;
    

=head2 Run time

  use DBI;
  use lib::DBI;
  my $dbh = DBI->connect(...);
  lib::DBI->config(dbh=>$dbh, ...);
  lib::DBI->module('Foo::Bar', compile=>1,);
  my $foo = Foo::Bar->new();
  my $mod_content = lib::DBI->module('Foo::Bar', compile=>0,);
  
  # or object
  my $lib = lib::DBI->new(dbh=>$dbh, ...);
  $lib->module('Foo::Bar', compile=>1,);
  my $foo = Foo::Bar->new();
  my $mod_content = $lib->module('Foo::Bar', compile=>0,);
  
  # sub
  my $evalres = lib::DBI->sub('Foo->bar', compile=>1,);
  my $subrow = lib::DBI->sub('Foo->bar', compile=>0,);
  
  # or object
  my $evalres = $lib->sub('Foo->bar', compile=>1,);
  my $subrow = $lib->sub('Foo->bar', compile=>0,);

=head1 CONFIG OPTIONS

There are two modes of configure:

=over 4

=item * Package/class level.

  lib::DBI->config(...);

=item * Instance/object level.

  $lib->config(...);

=head2 dbh

  dbh => DBI->connect(...),

=head2 connect

Arrayref pass to L<DBI/"connect"> for L</dbh> option create. Usefull only for compile time case.

  connect => ['DBI:Pg:dbname=test', 'postgres', undef, {pg_enable_utf8 => 1,...}],

=head2 do

Arrayref values pass to L<DBI/"do"> during only for compile time case.

  do => ['set search_path to 'foo schema'],

=head2  cols_name

Column names mapping to your db table modules. Defaults to:

  cols_name => {
    module_name =>"name",  # sql modules."name"
    module_id =>"id",      # sql modules."id"
    sub_name => "name",    # sql subs."name"
    sub_id => "id",        # sql subs."id"
    sub_code => "code",    # sql subs."code"
  },

=head2 compile

Boolean runtime only option. Defaults to true.

  compile => 1,

=head2 debug

Boolean option. Default to C<$ENV{DEBUG_LIB_DBI} // 0>

  debug => 1,

=head2 cache

False value for disable cached data or hashref where is DB data will stored. Defaults to internal hashref and cache is enabled.

  cache=>0,

=head2 module_sql

String of SQL query for fetch module content from DB tables. Defaults as examle to:

  module_sql => <<END_SQL,
select s.*
from 
  modules m
  join subs s on s.module_id=m.id
where
  ( m.name=? or m.id=? )
  and (m.disabled is null or m.disabled = false)
  and (s.disabled is null or s.disabled = false)
  and (s.autoload is null or s.autoload = false)
order by s."order"
END_SQL

=head2 module_bind_order

Arrayref of modules and subroutines tables column names which in where clause of L</"module_sql">. Lenght and order of array must соотв placeholhers inside where clause of  L</"module_sql">. Defaults as for example for L</"module_sql"> statement to:

  module_bind_order => [qw(module_name module_id )],

=head2 sub_sql

String of SQL query for fetch subroutine content from DB tables. Defaults as examle to:

  sub_sql => <<END_SQL,
select s.*
from modules m
  join subs s on s.module_id=m.id
where
  ((( m.name=? or m.id=? ) and s.name=?) or s.id=?)
  and (m.disabled is null or m.disabled = false)
  and (s.disabled is null or s.disabled = false)
order by s."order"
END_SQL

=head2 sub_bind_order

Arrayref of modules and subroutines tables column names which in where clause of L</"sub_sql">. Lenght and order of array must соотв placeholhers inside where clause of  L</"sub_sql">. Defaults as for example for L</"sub_sql"> statement to:

  sub_bind_order => [qw(module_name module_id sub_name sub_id)],


=head1 SUBROUTINES/METHODS

=head2 new

    my $lib = lib::DBI->new(<pair opts>)

Create object-dispatcher with own config. See L</"CONFIG OPTIONS">.

=head2  config

Get or set config options for package and instances. See L</"CONFIG OPTIONS">.

  # get a whole package/class config hashref
  lib::remote->config();
  
  # get a whole object config hashref
  $lib->config();
  
  # get package/class config key
  lib::DBI->config('dbh');
  
  # get object config key
  $lib->config('dbh');
  
  # set package/class config keys
  lib::DBI->config('dbh'=>..., <...> => ...,);
  
  # set object config keys
  $lib->config('dbh'=>..., <...> => ...,);

=head2 module

Fetch module content from DB tables and depends on L</"compile"> option compile content. If compile module content then returns module name else returns joined module content text. See L</"CONFIG OPTIONS">.

  lib::DBI->module(...)
  # or object
  $lib->module(...)

=head2 sub

Fetch subroutine content from DB tables and depends on L</"compile"> option compile content. If compile subroutine content then returns result of evaluted subroutine content else returns db hashref record. See L</"CONFIG OPTIONS">.

  lib::DBI->sub(...)
  # or object
  $lib->sub(...)


=head1 Example PostgreSQL scheme

=head2 One global sequence

One global sequence for autoincrement IDs of tables rows IDs of whole scheme/db.

  CREATE SEQUENCE IF NOT EXISTS "ID";

=head2 Table "modules"

  CREATE TABLE IF NOT EXISTS "modules" (
    id integer default nextval('"ID"'::regclass) not null primary key,
    ts timestamp without time zone not null default now(),
    name character varying not null unique,
    descr text,
    disabled boolean
  );

=head2 Table "subs"

  CREATE TABLE IF NOT EXISTS "subs" (
    id integer default nextval('"ID"'::regclass) not null primary key,
    ts timestamp without time zone not null default now(),
    module_id int not null REFERENCES "modules"(id),
    name character varying not null unique,
    code text,
    content_type text,
    last_modified timestamp without time zone not null,
    "order" numeric,
    disabled boolean,
    autoload boolean
  );



=head1 AUTHOR

Mikhail Che, C<< <m.che at cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/lib-DBI/issues>.

=head1 COPYRIGHT

Copyright 2016-2017 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=head1 DISTRIB

$ module-starter --module=lib::DBI --author=”Mikhail Che” --email=”mche[-at-]cpan.org” --builder=Module::Build --license=perl --verbose

$ perl Build.PL

$ ./Build test

$ ./Build dist

=cut

# End of lib::DBI

__END__

sub import { # это разбор аргументов после строк use lib::...
    my $pkg = shift;# is eq __PACKAGE__
    unshift @_, $PKG if ref $_[0] eq 'HASH';
    push @_, {} if @_ == 1; # просто имя модуля без опций
    my %arg = @_;
    $pkg->config(@_); # save
    my $config_g = $Config{$PKG}{modules};
    for my $mod (keys %arg) {
        next if $mod eq $PKG;
        my $config_m = $Config{$mod};
        my $require = $config_m->{require} // $config_g->{require};
        my $debug = $config_m->{debug} // $config_g->{debug};
        if ( $require ) {
            #~ eval "use $module;";# вот сразу заход в диспетчер @INC
            eval {require $mod};
            if ($@) {
                croak "$pkg->import: проблемы компиляции модуля [require $mod]: $@";
            } elsif ($debug) {
                carp "$pkg->import: success compile [require $mod]\n";
            }
        }
        my $import = $config_m->{import};
        if ($require && $import && @$import) {
            eval { $mod->import(@$import) };
            if ($@) {
                carp "$mod->import: возможно проблемы с импортом: $@";
            } elsif ($debug) {
                carp "$mod->import: success [ @$import ]\n";
            }
        }
    }
}