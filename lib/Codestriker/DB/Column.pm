###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Object which represents a column specification for a database table.

package Codestriker::DB::Column;

use strict;
use warnings;

# Export the type values.
use vars qw ( $TYPE );

# List of column datatypes that can be used in specifying a column.
$Codestriker::DB::Column::TYPE = {
    TEXT => 0,
    VARCHAR => 1,
    INT32 => 2,
    INT16 => 3,
    DATETIME => 4,
    FLOAT => 5
};

# A column object consists of a name, type, optional type parameter and
# an indication as to whether it is an autoincrement field or not (integer
# types only), whether the field is a part of the primary key and whether the
# field is mandatory.  By default, the field is mandatory.
#
# usage: Column->new({name=>"id", type=>INT32_TYPE, autoincrement=>1,
#                     pk=>1, mandatory=>1});
#
sub new {
    my $type = shift;
    my %params = @_;

    my $self = {};
    $self->{name} = $params{name};
    $self->{type} = $params{type};

    if ($self->{type} == $Codestriker::DB::Column::TYPE->{VARCHAR}) {
	$self->{length} = $params{length};
    }

    if (exists $params{autoincrement}) {
	$self->{autoincrement} = $params{autoincrement};
    } else {
	$self->{autoincrement} = 0;
    }

    if (exists $params{autoincr}) {
	$self->{autoincrement} = $params{autoincr};
    } else {
	$self->{autoincrement} = 0;
    }

    if (exists $params{pk}) {
	$self->{pk} = $params{pk};
    } else {
	$self->{pk} = 0;
    }

    if (exists $params{mandatory}) {
	$self->{mandatory} = $params{mandatory};
    } else {
	$self->{mandatory} = 1;
    }

    return bless $self, $type;
}

# Return the name of the column.
sub get_name {
    my $self = shift;
    return $self->{name};
}

# Return the type of the column.
sub get_type {
    my $self = shift;
    return $self->{type};
}

# Indicate if the column is an autoincrement or not.
sub is_autoincrement {
    my $self = shift;
    return $self->{autoincrement};
}

# Indicate if the column is a part of the primary key.
sub is_primarykey {
    my $self = shift;
    return $self->{pk};
}

# Indicate if the column is mandatory.
sub is_mandatory {
    my $self = shift;
    return $self->{mandatory};
}
    
# Return the varchar length.
sub get_length {
    my $self = shift;
    return $self->{length};
}

1;
