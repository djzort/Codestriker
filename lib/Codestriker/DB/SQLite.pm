###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

package Codestriker::DB::SQLite;

use strict;
use DBI;
use Codestriker;
use Codestriker::DB::Database;

# Module for handling a SQLite embedded database.

@Codestriker::DB::SQLite::ISA = ("Codestriker::DB::Database");

# Type mappings.
my $_TYPE = {
    $Codestriker::DB::Column::TYPE->{TEXT}	=> "text",
    $Codestriker::DB::Column::TYPE->{VARCHAR}	=> "varchar",
    $Codestriker::DB::Column::TYPE->{INT32}	=> "integer",
    $Codestriker::DB::Column::TYPE->{INT16}	=> "integer",
    $Codestriker::DB::Column::TYPE->{DATETIME}	=> "datetime",
    $Codestriker::DB::Column::TYPE->{FLOAT}	=> "numeric"
};

# Create a new SQLite database object.
sub new {
    my $type = shift;
    
    # Database is parent class.
    my $self = Codestriker::DB::Database->new();
    return bless $self, $type;
}

# Return the DBD module this is dependent on.
sub get_module_dependencies {
    return { name => 'DBD::SQLite', version => '0' };
}

# Retrieve a database connection.
sub get_connection {
    my $self = shift;

    # SQLite supports transactions, don't enable auto_commit.
    return $self->_get_connection(0, 1);
}

# Return the mapping for a specific type.
sub _map_type {
    my ($self, $type) = @_;
    return $_TYPE->{$type};
}    

# Autoincrement type for SQLite.  No need to set this, as by default if
# no entry is set into an integer primary key field, it will act as an
# auto-increment field, provided it is the first column in a table.
sub _get_autoincrement_type {
    return "";
}

# Indicate if the LIKE operator can be applied on a "text" field.
# For SQLite, this is true.
sub has_like_operator_for_text_field {
    my $self = shift;
    return 1;
}

# Function for generating an SQL subexpression for a case insensitive LIKE
# operation.
sub case_insensitive_like {
    my ($self, $field, $expression) = @_;
    
    $expression = $self->{dbh}->quote($expression);

    # SQLite is case insensitive by default, no need to do anything.
    return "$field LIKE $expression";
}

1;
