package lib::DBI;

use 5.010;
use strict;
use utf8;
#~ use warnings FATAL => 'all';
use Carp qw(croak carp);

=encoding utf8

=head1 lib::DBI

Доброго всем! Доброго здоровья! Доброго духа!

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !


=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';
my $PKG = __PACKAGE__;

my %CACHE= (# cache of loaded subs
    '<mod | sub name|id>'=> {},# 435346/Начало
        #code_eval
        # колонки запроса
);

my %Config = (## global default options
  dbh => undef,
  cols_map => {
    module_name =>"name",
    module_id =>"id",
    sub_name => "name",
    sub_id => "id",
    sub_code => "code",
  },
  prepare=>'cached',# 
  compile => 1, # run time only for ->module(...)
  type=> 'perl',
  debug => $ENV{DEBUG_LIB_DBI} // 0,
  cache=>\%CACHE, # ???
  module_sql => <<END_SQL, # SQL or DBI statement for extract rows/blocks of module
select ---m.id as module_id, m.name as module_name---, m.alias as module_alias
s.*
from modules m
join refs r on m.id=r.id1
join subs s on s.id=r.id2
where ( m.name=? or m.id=? )
and (not coalesce(m.disabled, false))
and (not coalesce(s.disabled, false))
and (not coalesce(s.autoload, false))
order by s.order
;
END_SQL
    module_bind_order => [qw(module_name module_id )],
    #~ bind_arg_names => [qw(id alias name)], # bind VALUES to {modules}{select}, default [$module_id, $alias, $mod]
    #~ code_col => 'code',# name of column with source code of parts of module
    #~ module_name => undef, # apply row package <module name>; to top source
    #~ access => undef, # SQL or DBI statement for check access to loaded module
    #~ bind_access => [], # bind VALUES to {modules}{access}
    #~ join=>"\n", # rows concatenate
    #~ type=>"perl",
    #~ import=>[],# Module->import()
    #~ require=>1, # compile time only -  eval require <module>
    #~ _rows => [],# store cache $dbh->selectall_arrayref (order!)
  sub_sql => <<END_SQL, # SQL or DBI statement for extract row of anonimous sub
select ---m.id as module_id, m.name as module_name --, m.alias as module_alias
s.*
from modules m
  join refs r on m.id=r.id1
  join subs s on s.id=r.id2
where (( m.name=? or m.id=? )
  and s.name=?) or s.id=?
and (not coalesce(m.disabled, false))
and (not coalesce(s.disabled, false))
order by s.order
;
END_SQL
  sub_bind_order => [qw(module_name module_id sub_name sub_id)],

);

BEGIN {
  push @INC, sub {# диспетчер
    my $self = shift;# эта функция CODE(0xf4d728) вроде не нужна
    my $mod = shift;#Имя
    my $content = module_content($mod, %CONFIG, compile=>0, type => 'perl', debug => 1,)
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
  
  if (!$arg{module_name} && $mod && $arg{type} eq 'perl') {
    $mod =~ s|/+|::|g;
    $mod =~ s|\.pm$||g;
  }
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
  
    my $sth = $arg{prepare} eq 'cached'
      ? $dbh->prepare_cached($arg{module_sql})
      : $dbh->prepare($arg{module_sql})
      if $arg{module_sql};
    
    my @bind = @arg{ @{$arg{module_bind_order}} };
    $rows = $dbh->selectall_arrayref($sth, {Slice=>{},}, @bind);
    $arg{debug} ? carp "Query content of the module [$arg{module_name}#$arg{module_id] returns empty recordset" : 1
      and return
      unless @$rows;
    
    if ($arg{cache}) {
      $arg{cache}{"module name $arg{module_name}"}{_rows} = $rows
        if $arg{module_name};
      
      $arg{cache}{"module id $arg{module_id}"}{_rows} = $rows
        if $arg{module_id};
    }
  
  } 
  
  return join $arg{join} // "\n\n", map {$_->{$arg{cols_map}{sub_code}};} @$rows;
  
};


sub new {
  return bless { config => {%Config, @_}, };
}


sub config {
=pod

=head2  config

! Проблема установки lib::DBI modules subs отдельных ключей
Get and set config

  lib::remote->config(); # get a whole package config hashref
  $obj->config(); # get a  whole object config hashref
  ...->config('dbh'); # get config key
  ...->config('dbh'=>..., <...> => ...,) set config keys
=cut
  my ($self, $pkg) = ref $_[0] ? (shift, undef) : (undef, shift);
  my $config = $self ? $self->{config} : \%Config;

  return $config
    unless @_;
  
  return %{$config->{$_[0]}}
    if @_ == 1;
    
  my %arg = @_;
  @$config{ keys %arg } = values %arg;
  return $self || $pkg;
}

sub module {
=pod
опции не сохраняет
=cut
  my ($self, $pkg) = ref $_[0] ? (shift, undef) : (undef, shift);
  my $mod = shift;
  my %arg = $self ? (%{$self->config()}, @_) : (%Config, @_);
  
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
  my %arg = $self ? (%{$self->config()}, @_) : (%Config, @_);
  
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
  my $sth = $arg{prepare} eq 'cached'
    ? $dbh->prepare_cached($arg{sub_sql})
    : $dbh->prepare($arg{sub_sql})
    if $arg{sub_sql};
  
  my @bind = @arg{ @{$arg{sub_bind_order}} };
  my $r = $dbh->selectrow_hashref($sth, undef, @bind)
    or $arg{debug} ? carp "Query content of the sub [$arg{module_name}::$arg->{sub_name}#$arg->{sub_id}] returns empty recordset" : 1
    and return;
  
  $arg{sub_name} ||= $r->{$arg{cols_map}{sub_name}}
    if $arg{cols_map}{sub_name};
    
  $arg{sub_id} ||= $r->{$arg{cols_map}{sub_id}}
    if $arg{cols_map}{sub_id};
  
  if ($arg{cache}) {
    $arg{cache}{"sub $arg{module_id}->$arg{sub_name}"} = $r;
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
  my $code = $r->{$arg->{cols_map}{sub_code}};
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


=head1 NAME

Compile time and run time eval packeges and subs source texts from DBI handle by querying SQL.

=head1 DESCRIPTION

Pragma lib::DBI push @INC, sub {...} once and this dispatcher will extracts Perl modules from the DBI sources at the compile time.
For run time there are class and object methods: ->module() and ->sub() which also compile sources of modules and subs.
For configure ->config() method.

Extracted source parts of modules and subs go to eval call or might be return raw text without eval.

For modules multirows parts will join on column code in order name column.

The name column of subs is like ailas for query but for AUTOLOAD they must have name like the sub on the code text.


=head1 SYNOPSIS

=head2 Compile time

    # global config 
    use lib::DBI {<global pair opts>}; # !!! first hash ref !!!
    use My::Foo::Module; # simple bind name 'My::Foo::Module' to SQL-query ({modules}{select} in global config of lib::DBI)
    my $foo = My::Foo::Module->new(...);
    ...
    # auto require module
    use lib::DBI 'My::Foo::Module';
    my $foo = My::Foo::Module->new(...);
    ...
    # configure and load some module with personal options
    use lib::DBI 'My::Bar::Module' => {<module pair opts>}; #
    
    # one line global config and load the module and his opts
    use lib::DBI {<global pair opts>}, 'My::Bar::Module' => {<module pair opts>};# !!! First hash ref is a global config !!!

=head2 Run time

=head3 Functional style

    # modules
    lib::DBI->module('My::Baz::Module',); # same as use My::Baz::Module;
    My::Baz::Module->...;
    # extract content, not compile
    my $content = lib::DBI->module('My::Biz::Module', compile=>0, ...); #<pair opts>
    # execute one line
    lib::DBI->module('My::Baz::Module', ...)->new(...)->foo(...);# default compile=>1
    # dispatcher
    my $disp = lib::DBI->new(...);
    $disp->module(...)# same as lib::DBI->module but
    
    
    # subs
    lib::DBI->sub('Foo::Bar->baz',...); # auto delimeter '->' for <module name> <sub name>
    lib::DBI->sub('Foo::Bar::baz',...); # auto delimeter '::' for <module name> <sub name>
    lib::DBI->sub([qw(Foo::Bar baz)],...); # array ref 2 elem [<module name>, <sub name>]
    my $res = Foo::Bar->baz(<args>);
    my $res = Foo::Bar::baz(<args>);
    # one line load and eval call with <args> and return results
    my $res = lib::DBI->sub('Foo::Bar->baz', call=>[<args>], ...);
    my $res = lib::DBI->sub('Foo::Bar::baz', call=>[<args>], ...);
    my $res = lib::DBI->sub(['Foo::Bar', 'baz'], delim=>'->', call=>[<args>], ...); # eval as Foo::Bar->baz(<args>) and return results
    my $res = lib::DBI->sub(['Foo::Bar', 'baz'], delim=>'::', call=>[<args>], ...); # eval as Foo::Bar::baz(<args>) and return results
    
    # anon
    my $res = lib::DBI->sub(['Foo::Bar', 'baz'], anon=>1, ...)->(<args>);
    my $res = lib::DBI->sub(['Foo::Bar', 'baz'], anon=>1, call=>[<args>],...);
    
    # extract text, not compile
    my $text = lib::DBI->sub(['Foo::Bar', 'baz'], compile=>0, ...); # joined \n if many records in order by

=head3 Object style - object dispatcher

    my $disp = lib::DBI->new(<pair opts>);
    $disp->module(...);
    $disp->sub(...);


=head1 SUBROUTINES/METHODS

=head2 new

    my $disp = lib::DBI->new(<pair opts>)

Create object-dispatcher with own config

=head2 module

    lib::DBI->module(...)
    $disp->module(...)

Compile the module. Return module name or module join text on success. Die on compile errors.

=head2 sub

    lib::DBI->sub(...)
    $disp->sub(...)

Create/redefine sub of module or an anonimous sub. Compile and may be call it.

Return depend on opts:
No set <call> and <anon> opts - full sub name on success eval source code or die on failure compile.
Set <call> and no set <anon> - results of calling this sub with the args or die on failure compile source code. <delim> opt also may be.
No set <call> and set <anon> - return anonimous subroutine or die on failure compile source code.
Set  <call> and <anon> opts - results of calling anonimous subroutine or die on failure compile source code and run code.



=head1 Config and options

Два режима конфигурирования lib::DBI:

=over 4

=item * Глобальный конфиг модуля, общие настройки для всех вызовов (прагма и функциональные вызовы)

=item * Создание отдельного объекта-диспетчера ->new() со свои конфигом

Прагма и ->config() сохраняют опции конфигурирования. При вызовах ->module() и ->sub() опции не сохраняются.

=head2 Dbh option

    dbh => DBI->connect(...),

=head2  Modules options

    select => # SQL or prepared DBI statement for select rows of module
    bind_select => [], #bind values for statement
    code_col => 'code', # name of code column on fetch select rows

=head2 Subs options

=head2 Default SQL structure as example

=head3 One global sequence

One global sequence for autoincrement IDs of tables rows of whole schema/db.

=head2 Table "modules" - 

Create table modules (
    id
    ts
    name (unique)
    alias (unique)
    descr
    disabled
);

=head3 Table "subs" - 

Create table subs (
    id
    ts
    name
    code
    content_type
    last_modified
    version
    order
    disabled
    autoload
);

=head3 Table "refs" - references between rows of tables schema

Create table refs (
    id
    ts
    id1
    id2
);

Create index unique (id1, id2);

=head1 AUTHOR

Mikhail Che, C<< <m.che at cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/lib-DBI/issues>.

=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.





=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc lib::DBI


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=lib-DBI>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/lib-DBI>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/lib-DBI>

=item * Search CPAN

L<http://search.cpan.org/dist/lib-DBI/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Mikhail Che.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

=head1 DISTRIB

$ module-starter --module=lib::DBI --author=”Mikhail Che” --email=”m.che@cpan.org” --builder=Module::Build --license=perl --verbose

$ perl Build.PL

$ ./Build test

$ ./Build dist

=cut

1; # End of lib::DBI
