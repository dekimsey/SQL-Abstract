
package SQL::Abstract;

=head1 NAME

SQL::Abstract - Generate SQL from Perl data structures

=head1 SYNOPSIS

    use SQL::Abstract;

    my $sql = SQL::Abstract->new(case => 'lower', cmp => 'like');

    my($stmt, @bind) = $sql->select($table, \@fields, \%where, \@order);

    my($stmt, @bind) = $sql->insert($table, \@values || \%fieldvals);

    my($stmt, @bind) = $sql->update($table, \%fieldvals, \%where);

    my($stmt, @bind) = $sql->delete($table, \%where);

    # Just generate the WHERE clause
    my($stmt, @bind)  = $sql->where(\%where);

=head1 DESCRIPTION

This module was inspired by the excellent L<DBIx::Abstract>.
However, in using the module I found that what I wanted to do
was generate SQL, but still retain complete control over my
statement handles and use the DBI interface. So, I set out
to create an abstract SQL generation module.

This module is based largely on L<DBIx::Abstract>. However,
there are several important differences, especially when it
comes to WHERE clauses. I have modified the concepts used
to make the SQL easier to generate from Perl data structures
and, IMO, more intuitive.

In particular, if you want to see if a field is within a set
of values, you can use an arrayref. Let's look at a specific
example:

    my $where = {
       worker => ['nwiger', 'bob', 'jim'],
       status => { '!=', 'completed' }
    };

    my($stmt, @bind) = $sql->select('requests', '*', $where);

This would give you something like this:

    $stmt = "SELECT * FROM requests WHERE
                ( ( worker = ? OR worker = ? OR worker = ? )
                   AND ( status != ? ) )";
    @bind = ('nwiger', 'bob', 'jim', 'completed');

Which you could then use in DBI code:

    my $sth = $dbh->prepare($stmt);
    $sth->execute(@bind);

Easy, eh?

=head1 FUNCTIONS

The functions are simple. There's one for each major SQL operation,
and a constructor you use first.

=cut

use Carp;
use strict;
use vars qw($VERSION %SQL);

$VERSION = do { my @r=(q$Revision: 1.10 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };

# Constant holding SQL statements. Needed for driver support
%SQL = (
    select  => "SELECT",
    from    => "FROM",
    insert  => "INSERT INTO",
    delete  => "DELETE FROM",
    update  => "UPDATE",
    set     => "SET",
    values  => "VALUES",
    where   => "WHERE",
    null    => "IS NULL",
    notnull => "IS NOT NULL",
    and     => "AND",
    or      => "OR",
    order   => "ORDER BY",
);

=head2 new(case => 'lower', cmp => 'like')

The C<new()> function takes a list of options and values, and returns
a new C<SQL::Abstract> object which can then be used to generate SQL
through the methods below. The options accepted are:

=over

=item case

If set to 'lower', then SQL will be generated in all lowercase. By
default SQL is generated in "textbook" case meaning something like:

    SELECT a_field FROM a_table WHERE some_field LIKE '%someval%'

=item cmp

This determines what the default comparison operator is. By default
it is C<=>, meaning that a hash like this:

    %where = (name => 'nwiger', email => 'nate@wiger.org');

Will generate SQL like this:

    ... WHERE name = 'nwiger' AND email = 'nate@wiger.org'

However, you may want loose comparisons by default, so if you set
C<cmp> to C<like> you would get SQL such as:

    ... WHERE name like 'nwiger' AND email like 'nate@wiger.org'

You can also override the comparion on an individual basis - see
the huge section on L</"WHERE CLAUSES"> at the bottom.

=back

=cut

sub new {
    my $self = shift;
    my $class = ref($self) || $self;
    my %opt = @_;

    # fix our case
    if ($opt{case} && $opt{case} eq 'lower') {
        map { $SQL{$_} = lc($SQL{$_}) } keys %SQL;
    }

    # default comparison is "=", but can be overridden
    $opt{cmp} ||= '=';

    return bless \%opt, $class;
}

=head2 insert($table, \@values || \%fieldvals)

This is the simplest function. You simply give it a table name
and either an arrayref of values or hashref of field/value pairs.
It returns an SQL INSERT statement and a list of bind values.

=cut

sub insert {
    my $self  = shift;
    my $table = shift;
    my $data  = shift;

    my $sql   = "$SQL{insert} $table ";
    my(@sqlf, @sqlv, @sqlq) = ();

    if (ref $data eq 'HASH') {
        while (my($k,$v) = each %$data) {
            # named fields, so must save names in order
            push @sqlf, $k;
            if (ref $v eq 'SCALAR') {
                # embedded literal SQL
                push @sqlq, $$v;
            } else { 
                push @sqlq, '?';
                push @sqlv, $v;
            }
        }

        local $" = ', ';     # join arrays w/ ,
        $sql .= "(@sqlf) $SQL{values} (@sqlq)";
    } elsif (ref $data eq 'ARRAY') {
        # just generate values(?,?) part
        for my $v (@$data) {
            if (ref $v eq 'SCALAR') {
                # embedded literal SQL
                push @sqlq, $$v;
            } else { 
                push @sqlq, '?';
                push @sqlv, $v;
            }
        }
    
        local $" = ', ';     # join arrays w/ ,
        $sql .= "$SQL{values} (@sqlq)";
    } elsif (ref $data eq 'SCALAR') {
        # literal SQL
        $sql .= $$data;
    }

    return wantarray ? ($sql, @sqlv) : $sql;
}

=head2 update($table, \%fieldvals, \%where)

This takes a table, hashref of field/value pairs, and an optional
hashref where clause. It returns an SQL UPDATE function and a list
of bind values.

=cut

sub update {
    my $self  = shift;
    my $table = shift;
    my $data  = shift;
    my $where = shift;

    my $sql   = "$SQL{update} $table $SQL{set} ";
    my(@sqlf, @sqlv) = ();

    while (my($k,$v) = each %$data) {
        if (ref $v eq 'SCALAR') {
            # embedded literal SQL
            push @sqlf, "$k = $$v";
        } else { 
            push @sqlf, "$k = ?";
            push @sqlv, $v;
        }
    }

    $sql .= join ', ', @sqlf;

    if ($where) {
        my($wsql, @wval) = $self->where($where);
        $sql .= $wsql;
        push @sqlv, @wval;
    }

    return wantarray ? ($sql, @sqlv) : $sql;
}

=head2 select($table, \@fields, \%where, \@order)

This takes a table, arrayref of fields (or '*'), optional hashref
where clause, and optional arrayref order by, and returns the
corresponding SQL SELECT statement and list of bind values.

=cut

sub select {
    my $self   = shift;
    my $table  = shift;
    my $fields = shift || ['*'];
    my $where  = shift;
    my $order  = shift;

    my $f = (ref $fields eq 'ARRAY') ? join ', ', @$fields : $fields;
    my $sql = "$SQL{select} $f $SQL{from} $table";

    my(@sqlf, @sqlv) = ();

    if ($where) {
        my($wsql, @wval) = $self->where($where);
        $sql .= $wsql;
        push @sqlv, @wval;
    }

    # order by?
    if ($order) {
        my $o = (ref $order eq 'ARRAY') ? join ', ', @$order : $order;
        $sql .= " $SQL{order} $o";
    }

    return wantarray ? ($sql, @sqlv) : $sql; 
}

=head2 delete($table, \%where)

This takes a table name and optional hashref where clause.
It returns an SQL DELETE statement and list of bind values.

=cut

sub delete {
    my $self  = shift;
    my $table = shift;
    my $where = shift;

    my $sql = "$SQL{delete} $table";
    my(@sqlf, @sqlv) = ();

    if ($where) {
        my($wsql, @wval) = $self->where($where);
        $sql .= $wsql;
        push @sqlv, @wval;
    }

    return wantarray ? ($sql, @sqlv) : $sql; 
}

=head2 where(\%where)

This is used just to generate the WHERE clause. For example,
if you have an arbitrary data structure and know what the
rest of your SQL is going to look like but want an easy way
to produce a WHERE clause, use this. It returns an SQL WHERE
clause and list of bind values.

=cut

# Finally, a separate routine just to handle where clauses
sub where {
    my $self  = shift;
    my $where = shift;

    # precatch for literal string
    return $where unless ref $where;

    # need a separate routine to properly wrap w/ "where"
    my $join = ref $where eq 'ARRAY' ? $SQL{or} : $SQL{and};
    my @ret = $self->_recurse_where($where, $join);

    return unless @ret;
    my $sql = shift @ret;
    $sql = " $SQL{where} " . $sql if $sql;

    return wantarray ? ($sql, @ret) : $sql; 
}

sub _recurse_where {
    my $self  = shift;
    my $where = shift;
    my $join  = shift || $SQL{and};

    my $wsql = '';
    my(@sqlf, @sqlv) = ();

    # If an arrayref, then we join each element
    if (ref $where eq 'ARRAY') {
        my @wsql = ();
        for my $el (@$where) {
            # skip empty elements, otherwise get invalid trailing AND stuff
            if (ref $el eq 'ARRAY') {
                next unless @$el;
            } elsif (ref $el eq 'HASH') {
                next unless %$el;
            }
            my @ret = $self->_recurse_where($el, $SQL{or});
            push @sqlf, shift @ret;
            push @sqlv, @ret;
        }
        $wsql = '( ' . join(" $join ", @sqlf) . ' )';
        return wantarray ? ($wsql, @sqlv) : $wsql; 
    }
    elsif (ref $where eq 'HASH') {
        while (my($k,$v) = each %$where) {
            if (! defined($v)) {
                # undef = null
                push @sqlf, "$k $SQL{null}";
            } elsif (ref $v eq 'ARRAY') {
                # multiple elements: multiple options
                # map into an array of hashrefs and recurse
                my @w = ();
                push @w, { $k => $_ } for @$v;
                my @ret = $self->_recurse_where(\@w, $SQL{or});
                push @sqlf, shift @ret;
                push @sqlv, @ret;
                $wsql = '( ' . join(" $join ", @sqlf) . ' )';
            } elsif (ref $v eq 'HASH') {
                # modified operator { '!=', 'completed' }
                my($f,$v) = each %$v;
                push @sqlf, "$k $f ?";
                push @sqlv, $v;
            } elsif (ref $v eq 'SCALAR') {
                # literal SQL
                push @sqlf, "$k $$v";
            } else {
                # standard key => val
                push @sqlf, "$k $self->{cmp} ?";
                push @sqlv, $v;
            }
        }
    } else {
        # literal sql
        push @sqlf, $where;
    }

    $wsql = '( ' . join(" $join ", @sqlf) . ' )';
    return wantarray ? ($wsql, @sqlv) : $wsql; 
}

=head1 WHERE CLAUSES

This module uses a variation on the idea from L<DBIx::Abstract>. It
is B<NOT>, repeat I<not> 100% compatible.

The easiest way is to show lots of examples. After each C<%where>
hash shown, it is assumed you ran:

    my($stmt, @bind) = $sql->where(\%where);

However, note that the C<%where> hash can be used directly in any
of the other functions as well, as described above.

So, let's get started. To begin, a simple hash:

    my %where  = (
        user   => 'nwiger',
        status => 'completed'
    );

Is converted to SQL C<key = val> statements:

    $stmt = "WHERE user = ? AND status = ?";
    @bind = ('nwiger', 'completed');

One common thing I end up doing is having a list of values that
a field can be in. To do this, simply specify a list inside of
an arrayref:

    my %where  = (
        user   => 'nwiger',
        status => ['assigned', 'in-progress', 'pending'];
    );

This simple code will create the following:
    
    $stmt = "WHERE user = ? AND ( status = ? OR status = ? OR status = ? )";
    @bind = ('nwiger', 'assigned', 'in-progress', 'pending');

Note this is not compatible with C<DBIx::Abstract>

If you want to specify a different type of operator for your comparison,
you can use a hashref:

    my %where  = (
        user   => 'nwiger',
        status => { '!=', 'completed' }
    );

Which would generate:

    $stmt = "WHERE user = ? AND status != ?";
    @bind = ('nwiger', 'completed');

So far, we've seen how multiple conditions are joined with C<AND>. However,
we can change this by putting the different conditions we want in hashes
and then putting those hashes in an array. For example:

    my @where = (
        {
            user   => 'nwiger',
            status => ['pending', 'dispatched'],
        },
        {
            user   => 'robot',
            status => 'unassigned',
        }
    );

This data structure would create the following:

    $stmt = "WHERE ( user = ? AND ( status = ? OR status = ? ) )
                OR ( user = ? AND status = ? ) )";
    @bind = ('nwiger', 'pending', 'dispatched', 'robot', 'unassigned');

If you want to include plain SQL verbatim, you must specify it as a
scalar reference, namely:

    my $inn = 'is not null';
    my %where = (
        pri  => { '>', 3 },
        name => \$inn
    );

This would create:

    $stmt = "WHERE pri > ? AND name is not null";
    @bind = (3);

Note you only get one bind parameter back.

=cut
    
# End of Perl code
1;
__END__

=head1 SEE ALSO

L<DBIx::Abstract>, L<SQL::Statement>

=head1 VERSION

$Id: Abstract.pm,v 1.10 2002/09/27 18:06:25 nwiger Exp $

=head1 AUTHOR

Copyright (c) 2001 Nathan Wiger <nate@sun.com>. All Rights Reserved.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut
