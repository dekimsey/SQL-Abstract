#!/usr/bin/perl -I. -w

use strict;
use vars qw($TESTING);
$TESTING = 1;
use Test;

# use a BEGIN block so we print our plan before SQL::Abstract is loaded
# we run each test TWICE to make sure _anoncopy is working
BEGIN { plan tests => 10 }

use SQL::Abstract;

my $sql = SQL::Abstract->new;

my @tests;

my ($sub_stmt, @sub_bind, $where);


($sub_stmt, @sub_bind) = ("SELECT c1 FROM t1 WHERE c2 < ? AND c3 LIKE ?",
                          100, "foo%");
$where = {
    foo => 1234,
    bar => {"IN ($sub_stmt)" => [@sub_bind]},
  };
push @tests, {
  where => $where,
  stmt => " WHERE ( bar IN (SELECT c1 FROM t1 WHERE c2 < ? AND c3 LIKE ?) AND foo = ? )",
  bind => [100, "foo%", 1234],
};


($sub_stmt, @sub_bind)
     = $sql->select("t1", "c1", {c2 => {"<" => 100}, 
                                 c3 => {-like => "foo%"}});
$where = {
    foo => 1234,
    bar => {"> ALL ($sub_stmt)" => [@sub_bind]},
  };
push @tests, {
  where => $where,
  stmt => " WHERE ( bar > ALL (SELECT c1 FROM t1 WHERE ( c2 < ? AND c3 LIKE ? )) AND foo = ? )",
  bind => [100, "foo%", 1234],
};


($sub_stmt, @sub_bind) 
     = $sql->select("t1", "*", {c1 => 1, c2 => \"> t0.c0"});
$where = {
    foo                  => 1234,
    "EXISTS ($sub_stmt)" => [@sub_bind],
  };
push @tests, {
  where => $where,
  stmt => " WHERE ( EXISTS (SELECT * FROM t1 WHERE ( c1 = ? AND c2 > t0.c0 )) AND foo = ? )",
  bind => [1, 1234],
};


$where = {
    "MATCH (col1, col2) AGAINST (?)" => ["apples"]
  };
push @tests, {
  where => $where,
  stmt => " WHERE ( MATCH (col1, col2) AGAINST (?) )",
  bind => ["apples"],
};



($sub_stmt, @sub_bind) 
  = $sql->where({age => [{"<" => 10}, {">" => 20}]});
$sub_stmt =~ s/^ where //i; # don't want "WHERE" in the subclause
$where = {
    lname           => {-like => '%son%'},
    "NOT ( $sub_stmt )" => [@sub_bind],
  };
push @tests, {
  where => $where,
  stmt => " WHERE ( NOT ( ( ( ( age < ? ) OR ( age > ? ) ) ) ) AND lname LIKE ? )",
  bind => [10, 20, '%son%'],
};



for (@tests) {
    local $" = ', ';
    #print "creating a handle with args ($_->{args}): ";


    # run twice
    for (my $i=0; $i < 2; $i++) {
        my($stmt, @bind) = $sql->where($_->{where}, $_->{order});
        my $bad = 0;
        for(my $i=0; $i < @{$_->{bind}}; $i++) {
            $bad++ unless $_->{bind}[$i] eq $bind[$i];
        }

        ok($stmt eq $_->{stmt} && @bind == @{$_->{bind}} && ! $bad) or 
                print "got\n",
                      "[$stmt] [@bind]\n",
                      "instead of\n",
                      "[$_->{stmt}] [@{$_->{bind}}]\n\n";
    }
}





