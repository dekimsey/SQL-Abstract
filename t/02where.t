#!/usr/bin/perl -I. -w

use strict;
use vars qw($TESTING);
$TESTING = 1;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { plan tests => 11 }

use SQL::Abstract;

# Make sure to test the examples, since having them break is somewhat
# embarrassing. :-(

my @handle_tests = (
    {
        where => {
            requestor => 'inna',
            worker => ['nwiger', 'rcwe', 'sfz'],
            status => { '!=', 'completed' }
        },
        order => [],
        stmt => " WHERE ( requestor = ? AND status != ? AND ( ( worker = ? ) OR"
              . " ( worker = ? ) OR ( worker = ? ) ) )",
        bind => [qw/inna completed nwiger rcwe sfz/],
    },

    {
        where  => {
            user   => 'nwiger',
            status => 'completed'
        },
        order => [qw/ticket/],
        stmt => " WHERE ( status = ? AND user = ? ) ORDER BY ticket",
        bind => [qw/completed nwiger/],
    },

    {
        where  => {
            user   => 'nwiger',
            status => { '!=', 'completed' }
        },
        order => [qw/ticket/],
        stmt => " WHERE ( status != ? AND user = ? ) ORDER BY ticket",
        bind => [qw/completed nwiger/],
    },

    {
        where  => {
            status   => 'completed',
            reportid => { 'in', [567, 2335, 2] }
        },
        order => [],
        stmt => " WHERE ( reportid IN ( ?, ?, ? ) AND status = ? )",
        bind => [qw/567 2335 2 completed/],
    },

    {
        where  => {
            status   => 'completed',
            reportid => { 'not in', [567, 2335, 2] }
        },
        order => [],
        stmt => " WHERE ( reportid NOT IN ( ?, ?, ? ) AND status = ? )",
        bind => [qw/567 2335 2 completed/],
    },

    {
        where  => {
            status   => 'completed',
            completion_date => { 'between', ['2002-10-01', '2003-02-06'] },
        },
        order => \'ticket, requestor',
        stmt => " WHERE ( completion_date BETWEEN ? AND ? AND status = ? ) ORDER BY ticket, requestor",
        bind => [qw/2002-10-01 2003-02-06 completed/],
    },

    {
        where => [
            {
                user   => 'nwiger',
                status => { 'in', ['pending', 'dispatched'] },
            },
            {
                user   => 'robot',
                status => 'unassigned',
            },
        ],
        order => [],
        stmt => " WHERE ( ( status IN ( ?, ? ) AND user = ? ) OR ( status = ? AND user = ? ) )",
        bind => [qw/pending dispatched nwiger unassigned robot/],
    },

    {
        where => {  
            priority  => [ {'>', 3}, {'<', 1} ],
            requestor => \'is not null',
        },
        order => 'priority',
        stmt => " WHERE ( ( ( priority > ? ) OR ( priority < ? ) ) AND requestor is not null ) ORDER BY priority",
        bind => [qw/3 1/],
    },

    {
        where => {  
            priority  => [ {'>', 3}, {'<', 1} ],
            requestor => { '!=', undef }, 
        },
        order => [qw/a b c d e f g/],
        stmt => " WHERE ( ( ( priority > ? ) OR ( priority < ? ) ) AND requestor IS NOT NULL )"
              . " ORDER BY a, b, c, d, e, f, g",
        bind => [qw/3 1/],
    },

    {
        where => {  
            priority  => { 'between', [1, 3] },
            requestor => { 'like', undef }, 
        },
        order => \'requestor, ticket',
        stmt => " WHERE ( priority BETWEEN ? AND ? AND requestor IS NULL ) ORDER BY requestor, ticket",
        bind => [qw/1 3/],
    },

    {
        where => {  
            id  => 1,
	    num => {
	     '<=' => 20,
	     '>'  => 10,
	    },
        },
        stmt => " WHERE ( id = ? AND num <= ? AND num > ? )",
        bind => [qw/1 20 10/],
    },



);

for (@handle_tests) {
      local $" = ', ';
      #print "creating a handle with args ($_->{args}): ";
      my $sql = SQL::Abstract->new;
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

