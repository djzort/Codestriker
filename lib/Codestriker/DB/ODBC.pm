###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

package Codestriker::DB::ODBC;

use strict;
use warnings;
use DBI;
use Codestriker;
use Codestriker::DB::Database;

# Module for handling an ODBC database.

our @ISA = ("Codestriker::DB::Database");

# Type mappings.
my $_TYPE = {
    $Codestriker::DB::Column::TYPE->{TEXT}	=> "text",
    $Codestriker::DB::Column::TYPE->{VARCHAR}	=> "varchar",
    $Codestriker::DB::Column::TYPE->{INT32}	=> "int",
    $Codestriker::DB::Column::TYPE->{INT16}	=> "smallint",
    $Codestriker::DB::Column::TYPE->{DATETIME}	=> "datetime",
    $Codestriker::DB::Column::TYPE->{FLOAT}	=> "float"
};

# Create a new ODBC database object.
sub new {
    my $type = shift;
    
    # Database is parent class.
    my $self = Codestriker::DB::Database->new();
    return bless $self, $type;
}

# Retrieve a database connection.
sub get_connection {
    my $self = shift;

    # ODBC implementations support transactions, don't enable auto_commit.
    return $self->_get_connection(0, 1);
}

# Return the mapping for a specific type.
sub _map_type {
    my ($self, $type) = @_;
    return $_TYPE->{$type};
}

# Autoincrement type for ODBC.
sub _get_autoincrement_type {
    return "IDENTITY";
}

# Method for retrieving the list of current tables attached to the database.
# For ODBC for SQL SERVER, $dbh->tables doesn't work, need to retrieve data
# from the sysobjects table.
sub get_tables() {
    my $self = shift;

    my @tables = ();
    my $table_select =
	$self->{dbh}->prepare_cached("SELECT name from sysobjects where type='U'");
    $table_select->execute();
    while (my ($table_name) = $table_select->fetchrow_array()) {
	push @tables, $table_name;
    }
    $table_select->finish();

    return @tables;
}

# Indicate if the LIKE operator can be applied on a "text" field.
# For ODBC (SQL Server), this is true.
sub has_like_operator_for_text_field {
    my $self = shift;
    return 1;
}

# Function for generating an SQL subexpression for a case insensitive LIKE
# operation.
sub case_insensitive_like(field, expression) {
    my ($self, $field, $expression) = @_;
    
    $expression = $self->{dbh}->quote($expression);

    # SQL Server is case insensitive by default, no need to do anything.
    return "$field LIKE $expression";
}

1;

