#!/usr/bin/perl -I. -w

use strict;
use vars qw($TESTING);
$TESTING = 1;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { plan tests => 25 }

use SQL::Abstract;

my @tests = (
      #1
      {
              func => 'select',
              args => ['test', '*'],
              stmt => 'SELECT * FROM test',
              bind => []
      },
      #1
      {
              func => 'select',
              args => ['test', [qw(one two three)]],
              stmt => 'SELECT one, two, three FROM test',
              bind => []
      },
      #3
      {
              func => 'select',
              args => ['test', '*', { a => 0 }, [qw/boom bada bing/]],
              stmt => 'SELECT * FROM test WHERE ( a = ? ) ORDER BY boom, bada, bing',
              bind => [0]
      },
      #4
      {
              func => 'select',
              args => ['test', '*', [ { a => 5 }, { b => 6 } ]],
              stmt => 'SELECT * FROM test WHERE ( ( a = ? ) OR ( b = ? ) )',
              bind => [5,6]
      },
      #5
      {
              func => 'select',
              args => ['test', '*', undef, ['id']],
              stmt => 'SELECT * FROM test ORDER BY id',
              bind => []
      },
      #6
      {
              func => 'select',
              args => ['test', '*', { a => 'boom' } , ['id']],
              stmt => 'SELECT * FROM test WHERE ( a = ? ) ORDER BY id',
              bind => ['boom']
      },
      #7
      {
              func => 'select',
              args => ['test', '*', { a => ['boom', 'bang'] }],
              stmt => 'SELECT * FROM test WHERE ( ( ( a = ? ) OR ( a = ? ) ) )',
              bind => ['boom', 'bang']
      },
      #8
      {
              func => 'select',
              args => [[qw/test1 test2/], '*', { 'test1.a' => { 'In', ['boom', 'bang'] } }],
              stmt => 'SELECT * FROM test1, test2 WHERE ( test1.a IN ( ?, ? ) )',
              bind => ['boom', 'bang']
      },
      #9
      {
              func => 'select',
              args => ['test', '*', { a => { 'between', ['boom', 'bang'] } }],
              stmt => 'SELECT * FROM test WHERE ( a BETWEEN ? AND ? )',
              bind => ['boom', 'bang']
      },
      #10
      {
              func => 'select',
              args => ['test', '*', { a => { '!=', 'boom' } }],
              stmt => 'SELECT * FROM test WHERE ( a != ? )',
              bind => ['boom']
      },
      #11
      {
              func => 'update',
              args => ['test', {a => 'boom'}, {a => undef}],
              stmt => 'UPDATE test SET a = ? WHERE ( a IS NULL )',
              bind => ['boom']
      },
      #12
      {
              func => 'update',
              args => ['test', {a => 'boom'}, { a => {'!=', "bang" }} ],
              stmt => 'UPDATE test SET a = ? WHERE ( a != ? )',
              bind => ['boom', 'bang']
      },
      #13
      {
              func => 'update',
              args => ['test', {'a-funny-flavored-candy' => 'yummy', b => 'oops'}, { a42 => "bang" }],
              stmt => 'UPDATE test SET a-funny-flavored-candy = ?, b = ? WHERE ( a42 = ? )',
              bind => ['yummy', 'oops', 'bang']
      },
      #14
      {
              func => 'delete',
              args => ['test', {requestor => undef}],
              stmt => 'DELETE FROM test WHERE ( requestor IS NULL )',
              bind => []
      },
      #15
      {
              func => 'delete',
              args => [[qw/test1 test2 test3/],
                       { 'test1.field' => \'!= test2.field',
                          user => {'!=','nwiger'} },
                      ],
              stmt => 'DELETE FROM test1, test2, test3 WHERE ( test1.field != test2.field AND user != ? )',
              bind => ['nwiger']
      },
      #16
      {
              func => 'insert',
              args => ['test', {a => 1, b => 2, c => 3, d => 4, e => 5}],
              stmt => 'INSERT INTO test (a, b, c, d, e) VALUES (?, ?, ?, ?, ?)',
              bind => [qw/1 2 3 4 5/],
      },
      #17
      {
              func => 'insert',
              args => ['test', [qw/1 2 3 4 5/]],
              stmt => 'INSERT INTO test VALUES (?, ?, ?, ?, ?)',
              bind => [qw/1 2 3 4 5/],
      },
      #18
      {
              func => 'insert',
              args => ['test', [qw/1 2 3 4 5/, undef]],
              stmt => 'INSERT INTO test VALUES (?, ?, ?, ?, ?, ?)',
              bind => [qw/1 2 3 4 5/, undef],
      },
      #19
      {
              func => 'update',
              args => ['test', {a => 1, b => 2, c => 3, d => 4, e => 5}],
              stmt => 'UPDATE test SET a = ?, b = ?, c = ?, d = ?, e = ?',
              bind => [qw/1 2 3 4 5/],
      },
      #20
      {
              func => 'update',
              args => ['test', {a => 1, b => 2, c => 3, d => 4, e => 5}, {a => {'in', [1..5]}}],
              stmt => 'UPDATE test SET a = ?, b = ?, c = ?, d = ?, e = ? WHERE ( a IN ( ?, ?, ?, ?, ? ) )',
              bind => [qw/1 2 3 4 5 1 2 3 4 5/],
      },
      #21
      {
              func => 'update',
              args => ['test', {a => 1, b => ["to_date(?, 'MM/DD/YY')", '02/02/02']}, {a => {'between', [1,2]}}],
              stmt => 'UPDATE test SET a = ?, b = to_date(?, \'MM/DD/YY\') WHERE ( a BETWEEN ? AND ? )',
              bind => [qw(1 02/02/02 1 2)],
      },
      #22
      {
              func => 'insert',
              args => ['test.table', {high_limit => \'max(all_limits)', low_limit => 4} ],
              stmt => 'INSERT INTO test.table (high_limit, low_limit) VALUES (max(all_limits), ?)',
              bind => ['4'],
      },
      #23
      {
              func => 'insert',
              new  => {bindtype => 'columns'},
              args => ['test.table', {one => 2, three => 4, five => 6} ],
              stmt => 'INSERT INTO test.table (five, one, three) VALUES (?, ?, ?)',
              bind => [['five', 6], ['one', 2], ['three', 4]],  # alpha order, man...
      },
      #24
      {
              func => 'select',
              new  => {bindtype => 'columns', case => 'lower'},
              args => ['test.table', [qw/one two three/], {one => 2, three => 4, five => 6} ],
              stmt => 'select one, two, three from test.table where ( five = ? and one = ? and three = ? )',
              bind => [['five', 6], ['one', 2], ['three', 4]],  # alpha order, man...
      },
      #25
      {
              func => 'update',
              new  => {bindtype => 'columns', cmp => 'like'},
              args => ['testin.table2', {One => 22, Three => 44, FIVE => 66},
                                        {Beer => 'is', Yummy => '%YES%', IT => ['IS','REALLY','GOOD']}],
               stmt => 'UPDATE testin.table2 SET FIVE = ?, One = ?, Three = ? WHERE '
                     . '( Beer LIKE ? AND ( ( IT LIKE ? ) OR ( IT LIKE ? ) OR ( IT LIKE ? ) ) AND Yummy LIKE ? )',
              bind => [['FIVE', 66], ['One', 22], ['Three', 44], ['Beer','is'],
                       ['IT','IS'], ['IT','REALLY'], ['IT','GOOD'], ['Yummy','%YES%']],
      },
);

use Data::Dumper;

for (@tests) {
      local $"=', ';

      my $new = $_->{new} || {};
      my $sql = SQL::Abstract->new(%$new);


      #print "testing with args (@{$_->{args}}): ";
      my $func = $_->{func};
      my($stmt, @bind) = $sql->$func(@{$_->{args}});
      ok($stmt eq $_->{stmt} && equal(\@bind, $_->{bind})) or
              print "got\n",
                    "[$stmt] [",Dumper(\@bind),"]\n",
                    "instead of\n",
                    "[$_->{stmt}] [",Dumper($_->{bind}),"]\n\n";
}

sub equal {
      my ($a, $b) = @_;
      return 0 if @$a != @$b;
      for (my $i = 0; $i < $#{$a}; $i++) {
              next if (! defined($a->[$i])) && (! defined($b->[$i]));
              if (ref $a->[$i] && ref $b->[$i]) {
                  return 0 if $a->[$i][0] ne $b->[$i][0]
                           || $a->[$i][1] ne $b->[$i][1];
              } else {
                  return 0 if $a->[$i] ne $b->[$i];
              }
      }
      return 1;
}

