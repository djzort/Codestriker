###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Object which represents an index for a database table.

package Codestriker::DB::Index;

use strict;
use warnings;

# Create a new Index object.
# usage: Index->new({name=>"table_index1", column_names=>["col1", "col2"]});
sub new {
    my $type = shift;
    my %params = @_;

    my $self = {};
    $self->{name} = $params{name};
    $self->{column_names} = $params{column_names};

    return bless $self, $type;
}

# Return the name of the index.
sub get_name {
    my $self = shift;
    return $self->{name};
}

# Return the column names used in the index as a string array.
sub get_column_names {
    my $self = shift;
    return $self->{column_names};
}

1;
