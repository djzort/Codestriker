###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Object which represents a database table specification.

package Codestriker::DB::Table;

use strict;
use warnings;

# A table consists of an array of Column objects, plus an array of indexes.
# usage: Table->new{name=>"table_name", columns=>\@columns, indexes=>\@indexes}
sub new {
    my $type = shift;
    my %params = @_;

    my $self = {};
    $self->{name} = $params{name};

    if (defined $params{columns}) {
	$self->{columns} = $params{columns};
    } else {
	$self->{columns} = [];
    }

    if (defined $params{indexes}) {
	$self->{indexes} = $params{indexes};
    } else {
	$self->{indexes} = [];
    }

    # Check that the column names in the indexes actually exist.
    my @columns = @{$params{columns}};

    # Check each index is valid for this table.
    foreach my $index (@{$params{indexes}}) {

	# Check each column in this index refers to a column in this table.
	foreach my $index_column (@{$index->get_column_names()}) {
	    my $found = 0;

	    # Check this column exists.
	    foreach my $column (@columns) {
		if ($column->get_name() eq $index_column) {
		    $found = 1;
		    last;
		}
	    }

	    if ($found == 0) {
		die "Index $index->get_name() has bad column $index_column\n";
	    }
	}
    }

    return bless $self, $type;
}

# Return the table name.
sub get_name {
    my $self = shift;
    return $self->{name};
}

# Return the columns associated with this table.
sub get_columns {
    my $self = shift;
    return $self->{columns};
}

# Return the indexes associated with this table.
sub get_indexes {
    my $self = shift;
    return $self->{indexes};
}

1;
