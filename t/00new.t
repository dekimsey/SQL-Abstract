#!/usr/bin/perl -I. -w

use strict;
use vars qw($TESTING);
$TESTING = 1;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { plan tests => 12 }

use SQL::Abstract;

my @handle_tests = (
      #1
      {
              args => {logic => 'OR'},
              stmt => 'SELECT * FROM test WHERE ( a = ? OR b = ? )'
      },
      #2
      {
              args => {},
              stmt => 'SELECT * FROM test WHERE ( a = ? AND b = ? )'
      },
      #3
      {
              args => {case => "upper"},
              stmt => 'SELECT * FROM test WHERE ( a = ? AND b = ? )'
      },
      #4
      {
              args => {case => "upper", cmp => "="},
              stmt => 'SELECT * FROM test WHERE ( a = ? AND b = ? )'
      },
      #5
      {
              args => {cmp => "=", logic => 'or'},
              stmt => 'SELECT * FROM test WHERE ( a = ? OR b = ? )'
      },
      #6
      {
              args => {cmp => "like"},
              stmt => 'SELECT * FROM test WHERE ( a LIKE ? AND b LIKE ? )'
      },
      #7
      {
              args => {logic => "or", cmp => "like"},
              stmt => 'SELECT * FROM test WHERE ( a LIKE ? OR b LIKE ? )'
      },
      #8
      {
              args => {case => "lower"},
              stmt => 'select * from test where ( a = ? and b = ? )'
      },
      #9
      {
              args => {case => "lower", cmp => "="},
              stmt => 'select * from test where ( a = ? and b = ? )'
      },
      #10
      {
              args => {case => "lower", cmp => "like"},
              stmt => 'select * from test where ( a like ? and b like ? )'
      },
      #11
      {
              args => {case => "lower", convert => "lower", cmp => "like"},
              stmt => 'select * from test where ( lower(a) like lower(?) and lower(b) like lower(?) )'
      },
      #12
      {
              args => {convert => "Round"},
              stmt => 'SELECT * FROM test WHERE ( ROUND(a) = ROUND(?) AND ROUND(b) = ROUND(?) )',
      },
);

for (@handle_tests) {
      local $" = ', ';
      #print "creating a handle with args ($_->{args}): ";
      my $sql = SQL::Abstract->new($_->{args});
      my($stmt, @bind) = $sql->select('test', '*', { a => 4, b => 0});
      ok($stmt eq $_->{stmt} && $bind[0] == 4 && $bind[1] == 0) or 
              warn "got\n",
                    "[$stmt], [@bind]\n",
                    "instead of\n",
                    "[$_->{stmt}] [4, 0]\n\n";
}

