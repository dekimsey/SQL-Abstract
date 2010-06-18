#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use SQL::Abstract::Test import => ['is_same_sql'];

use Data::Dumper;
use SQL::Abstract;

my @handle_tests = (
   {
       where => { -not_bool => [ a => 1, b => 2] },
       stmt => 'SELECT * FROM test FORCE INDEX ( foo_base, monkey_do ) WHERE NOT ( a = ? OR b = ? )',
       stmt_quoted => 'SELECT * FROM `test` FORCE INDEX ( `foo_bar`, `monkey_do` ) WHERE NOT ( `a` = ? OR `b` = ? )',
       index => \{ -force => [qw(foo_bar monkey_do)] },
   },
   {
       where => [ a => 1, b => 2],
       stmt => 'SELECT * FROM test USE INDEX ( foo_base, monkey_do ) WHERE ( ( a = ? OR b = ? ) )',
       stmt_quoted => 'SELECT * FROM `test` USE INDEX ( `foo_bar`, `monkey_do` ) WHERE ( ( `a` = ? OR `b` = ? ) )',
       index => \[qw(foo_bar monkey_do)],
   },
   {
       where => [ a => 1, b => 2],
       stmt => 'SELECT * FROM test IGNORE INDEX ( foo_base, monkey_do ) WHERE ( ( a = ? OR b = ? ) )',
       stmt_quoted => 'SELECT * FROM `test` IGNORE INDEX ( `foo_bar`, `monkey_do` ) WHERE ( ( `a` = ? OR `b` = ? ) )',
       index => \{ -ignore => [qw(foo_bar monkey_do)] },
   },

);
my @handle_die_tests = (
   {
       index => \{ -ignore => [qw(chicken)], -force => [qw(foo_bar monkey_do)] },
       die => qr/Only one type of index can be specified in a query .+/,
   },
   {
       index => \{ -ignore => {foo_bar => 'monkey_do'} },
       die => qr/A list of indexes must be specified./,
   },
   {
       index => \[],
       die => qr/A list of indexes must be specified./,
   },
   {
       index => \{ -ignore => 'bah' },
       die => qr/A list of indexes must be specified./,
   },
);

plan tests => ( @handle_tests * 2 * 2) + (@handle_die_tests);

for my $case (@handle_tests) {
    local $Data::Dumper::Terse = 1;
    my $sql = SQL::Abstract->new;
    my $sqlq = SQL::Abstract->new({quote_char => '`'});
    my($stmt);
    lives_ok (sub { 
      ($stmt) = $sql->select('test', '*', $case->{index}, $case->{where}, $case->{order});
      is_same_sql($stmt, $case->{stmt})
        || diag "Search term:\n" . Dumper $case->{where};
    });
    lives_ok(sub {
      ($stmt) = $sqlq->select('test', '*', $case->{index}, $case->{where}, $case->{order});
      is_same_sql($stmt, $case->{stmt_quoted})
        || diag "Search term:\n" . Dumper $case->{where};
    });
}

for my $die_case (@handle_die_tests) {
    local $Data::Dumper::Terse = 1;
    my $sql = SQL::Abstract->new;
    my($stmt, @bind);
    throws_ok (sub { 
      $sql->select('test', '*', $die_case->{index}, $die_case->{where});
    }, $die_case->{die}, "Failure to die with invalid index specification");
}

