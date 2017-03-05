package lib::DBI;

use 5.006;
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
    #~ $PKG =>{
  dbh => undef,
  modules => { # 
      select => <<END_SQL, # SQL or DBI statement for extract rows/blocks of module
select m.id as module_id, m.name as module_name, m.alias as module_alias
s.*
from modules m
join refs r on m.id=r.id1
join subs s on s.id=r.id2
where ( m.name=? or m.id=? )
and (m.disabled is null or m.disabled <> 1)
and s.disabled <> 1
and s.autoload <> 1
order by s.order
;
END_SQL
    prepare=>'cached',# 
    #~ bind_arg_names => [qw(id alias name)], # bind VALUES to {modules}{select}, default [$module_id, $alias, $mod]
    code_col => 'code',# name of column with source code of parts of module
    #~ module_name => undef, # apply row package <module name>; to top source
    #~ access => undef, # SQL or DBI statement for check access to loaded module
    #~ bind_access => [], # bind VALUES to {modules}{access}
    join=>"\n", # rows concatenate
    type=>"perl",
    #~ import=>[],# Module->import()
    require=>1, # compile time only -  eval require <module>
    compile => 1, # run time only for ->module(...)
    debug => 0,
    cache=>\%CACHE, # ???
    #~ _rows => [],# store cache $dbh->selectall_arrayref (order!)
  },
  subs => {
      select => <<END_SQL, # SQL or DBI statement for extract row of anonimous sub
select m.id as module_id, m.name as module_name, m.alias as module_alias
s.*
from modules m
  join refs r on m.id=r.id1
  join subs s on s.id=r.id2
where (( m.name=? or m.id=? )
  and s.name=?) or s.id=?
and m.disabled <> 1
and s.disabled <> 1
order by s.order
;
END_SQL
    #~ bind => [], # bind VALUES to {subs}{select}, default <module name> and <sub name>
    code_col => 'code',# name of column with source code of parts of module
    prepare=>'cached',
    #~ sub_name =>undef, # name of loaded anonimous sub
    #~ access => undef, # SQL or DBI statement for check access to loaded sub
    #~ bind_access => [], # bind VALUES to {subs}{access}
    compile => 1, #  eval and return code ref
    cache => \%CACHE, # 0 - dont save in cache subs
  },
    #~ },
    #~ 'Foo::Module::XYZ' => {# ключ соответствует с колонкой modules.name
        #~ # ключи полностью идентичны keys {__PACKAGE__}{module}
    #~ },

);

BEGIN {
    push @INC, sub {# диспетчер
        my $self = shift;# эта функция CODE(0xf4d728) вроде не нужна
        my $mod = shift;#Имя
        my $content = module_content($mod, type=>'perl', prepare=>'cached', join=>"\n", cache=>1,)
            or return undef;
        open my $fh, '<', \$content or die "Cant open: $!";
        return $fh;
    };
}

sub module_content {# text module extract
  my $mod = shift; # Module<id> or alias or name
  my %arg = @_;
  my $dbh = $arg{dbh} || $Config{dbh}
    or return;
  my $config = $Config{modules};
  $arg{type} ||= $config->{type};
  
  #~ $arg{alias} //= $mod;# as is
  if ($arg{type} eq 'perl') {
    $mod =~ s|/+|::|g;
    $mod =~ s|\.pm$||g;
  }
  $arg{id} //= ($mod =~ /^Module_id_(\d+)$/i)[0]; # Module43252
  
  #~ return
    #~ unless $arg{name} || $arg{id};
  
  #~ my $opt_m = $Config{$mod} ||= {};
  #~ my $opt_g = $Config{$PKG}{modules};
  #~ $arg{debug} //= $opt_m->{debug} // $opt_g->{debug};
  
  $arg{debug} //= $config->{debug};
  #~ $arg{module_name} ||= $opt_m->{module_name};# || $mod;
  #~ $arg{code_col} ||= $opt_m->{code_col} || $opt_g->{code_col};
  $arg{code_col} ||= $config->{code_col};
  $arg{join} //= $config->{join};
  
  $arg{cache} //= $config->{cache};
  my $cache = $arg{cache}{'module name '.($mod || '')} || $arg{cache}{'module id '.($arg{id} || '')}
    if $arg{cache};
  
  my $rows = $cache->{_rows}# строки модуля из кэша
    if  $cache;
  
  unless ($rows) {# не исп кэш или нет модуля в кэше
  
    $arg{select} ||= $config->{select}
      or return;
    
    $arg{prepare} //= $config->{prepare};
    
    my $sth = $arg{prepare} eq 'cached'
      ? $dbh->prepare_cached($arg{select})
      : $dbh->prepare($arg{select});
    
    #~ $arg{bind_arg_names} ||= $config->{bind_arg_names};
    
    my @bind = @{$arg{bind}} || ($mod, $arg{id});# id, alias, name (transform name)
    $rows = $dbh->selectall_arrayref($sth, {Slice=>{},}, @bind);
    #~ $arg{debug} && carp "Couldn't query content the module [$mod]"
    return
      unless @$rows;
    
    
    if ($arg{cache}) {
      $arg{cache}{'module name '.$mod}{_rows} = $rows
        unless $arg{id};
      $arg{cache}{'module id '.$arg{id}}{_rows} = $rows
        if $arg{id};
    }
  
  } 
  
  return join $arg{join}, $arg{name} && $arg{type} eq 'perl' ? "package $arg{name};" : (), map {$_->{$arg{code_col}};} @$rows
  
};


sub new {
#~ =pod
    #~ ->new(dbh=>..., modules => {...}, subs => {...})
#~ =cut
  my $pkg = shift;
  my %config = %Config;
  my %arg = @_;
  $config{$_}
    ? ref $arg{$_} eq 'HASH'
      ? @{$config{$_}}{ keys %{$arg{$_}} } = values %{$arg{$_}}
      : $config{$_} = $arg{$_}
    : undef
    for qw(dbh modules subs);
  my $self = bless { config => \%config, };# get a whole copy %Config
  #~ $self->config(@_); # set 
  return $self;
}


sub config {
=pod

=head2  config

! Проблема установки lib::DBI modules subs отдельных ключей
Get and set config

  lib::remote->config(); # get a whole package config
  $obj->config(); # get a  whole object config
  ...->config('dbh'); # get single config key
  ...->config('dbh'=>..., <...> => ...,) set config keys
=cut
  my ($self, $pkg) = ref $_[0] ? (shift, undef) : (undef, shift);
  #~ my $config = ref $pkg_or_obj ? $pkg_or_obj : \%Config;
  my $config = $self ? $self->{config} : \%Config;

  return $config
    unless @_;
  
  return %{$config->{$_[0]}} if @_ == 1;#$config->{$_[0]};
      #~ return $config->{__PACKAGE__}{$_[0]} if defined $config->{__PACKAGE__}{$_[0]};
  #~ }
  #~ return $config->{$_[0]}{$_[1]} if @_ == 2 && ! ref $_[1]; # 'lib::DBI'=>'dbh'
  
  my %arg = @_;
  @$config{ keys %arg } = values %arg;
  #~ for my $mod (keys %arg) {
      #~ @{$config->{$mod}}{keys %{$arg{$mod}}} = values %{$arg{$mod}};
  #~ }
  return $self || $pkg;
}

sub module {
=pod
опции не сохраняет
=cut
    #~ my $pkg_or_obj = shift;
    my ($self, $pkg) = ref $_[0] ? (shift, undef) : (undef, shift);
    my $mod = shift;
      #~ my $config = ref $pkg_or_obj ? $pkg_or_obj : \%Config;
    my $config = $self ? $self->{config}{modules} : $Config{modules};
    my %arg = (%$config, @_);
    
  
    #~ my $config_m = $config->{$mod};
    #~ my $config_g = $config->{$PKG}{modules};
    #~ $arg{debug} //= $config->{debug};
    #~ $arg{compile} //= $config->{compile};
    #~ $arg{name} = $mod;
    
    my $content = module_content($mod, %arg)
        or ($arg{debug} ? carp "Нет содержимого модуля [$mod]" : 1)
        and return undef;
    
    return $content
      unless $arg{compile};
    
    #~ $arg{module_name} ||= $mod;
    #~ if ($arg{compile}) {
    eval $content;
    if ($@) {
        croak "($pkg|$self)->module: проблемы компиляции модуля [$mod]: $@";
    } elsif ($arg{debug}) {
        carp "($pkg|$self)->module: success compile [$mod]\n";
    }
    #~ if ($arg{import} && @{$arg{import}}) {
        #~ eval { $arg{name}->import(@{$arg{import}}) };
        #~ if ($@) {
            #~ carp "$arg{module_name}->import: возможно проблемы с импортом: $@";
        #~ } elsif ($arg{debug}) {
            #~ carp "$arg{module_name}->import: success [@{$arg{import}}]\n";
        #~ }
    #~ }
    return $arg{name} || $mod;
    #~ } else {
        #~ return $content;
    #~ }
}

sub sub {
    my ($self, $pkg) = ref $_[0] ? (shift, undef) : (undef, shift);
    my $mod_sub = shift;
    my $config = $self ? $self->{config}{subs} : $Config{subs};
    my %arg = (%$config, @_);
    
    my ($mod, $sub) = ref($mod_sub) eq 'ARRAY'
      ? @$mod_sub
      : do {
        $mod_sub =~ s/(?:->|::)([\wа-я]+)$//i;
        ($mod_sub || $arg{module}, $1);
      };

    #~ $sub = [split /->|::/, $sub] unless ref($sub);
    #~ $sub->[1] ||= 'Начало';
    #~ my $mod = join $sub->[0..($#$sub-1)];# alias
    #~ $mod =~ s|/+|::|g;
    #~ $mod =~ s|\.pm$||g;
    $arg{module_id} //= ($mod =~ /^(\d+)$/i)[0]; # Module432524
    $arg{sub_id} //= ($sub =~ /^(\d+)$/i)[0];
    
    $arg{code_col} ||= $Config{subs}{code_col}
      or carp "[lib::DBI::subs] Нет code_col опции"
      and return;
    
    my $cache = $arg{cache}{"module id $arg{module_id}->$sub"} || $arg{cache}{"$mod->$sub"} || $arg{cache}{"sub id $arg{sub_id}"}
      if $arg{cache};
    
    $arg{compile} //= $Config{subs}{compile};
    if ($cache) {
      return $cache
        unless $arg{compile};
      #~ my $code_ref = $cache->{code_ref};
      $cache->{code_col} ||= $arg{code_col}
      return _eval $cache
        unless $cache->{code_ref};
      
      return $cache->{code_ref};
    }

    # try to select and eval code
    #~ my $opt_pkg = $Config{$PKG};
    my $dbh = $arg{dbh} || $Config{dbh}
      or carp "[lib::DBI::subs] Нет dbh соединения"
      and return;
    $arg{select} ||= $Config{subs}{select}
      or carp "[lib::DBI::subs] Нет select опции"
      and return;
    my $sth = $arg{prepare} eq 'cached'
      ? $dbh->prepare_cached($arg{select})
      : $dbh->prepare($arg{select});
    my @bind = @{$arg{bind}} || ($mod,  $arg{module_id}, $sub, $arg{sub_id});# id, alias, name (transform name)
    my $r = $dbh->selectrow_hashref($sth, undef, @bind)
      or return;
    #~ warn "Couldn't query content the module [$mod]"
        #~ and 
    
    if ($arg{cache}) {
      $arg{cache}{"$mod->$sub"} = $r
        unless $arg{module_id} && $arg{sub_id};
        
      $arg{cache}{"module id $arg{module_id}->$sub"} = $r
        if $arg{module_id} && !$arg{sub_id};
        
      $arg{cache}{"sub id $arg{sub_id}"} = $r
        if $arg{sub_id};
      
    }
    
    return $r
      unless $arg{compile};
    
    $r->{code_col} = $arg{code_col};
    return _eval $r;
}

sub _eval_sub {
    my $r = shift; # selected || cached row{} of sub
    my $code = $r->{$r->{code_col}};
    #~ $code =~ s|^\s*sub\s+{\s*|sub {\nmy \$self = \$r;\n|;
    my $eval = eval $code;
    if ($@) {
        croak "[lib::DBI::subs] Проблемы компиляции программы [$r->{module_name}->$r->{name}]: $@";
    } elsif ($r->{debug}) {
        carp "[lib::DBI::subs] Success compile [$r->{module_name}->$r->{name}]\n";
    }
    #~ die "Проблемы с кодом [][]: $@" if $@;
    if (ref($eval) eq 'CODE') {
        $r->{code_ref} = $eval;
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
