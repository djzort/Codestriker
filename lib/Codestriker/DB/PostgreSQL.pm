###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

package Codestriker::DB::PostgreSQL;

use strict;
use warnings;
use DBI;
use Codestriker;
use Codestriker::DB::Database;
use Codestriker::DB::Column;

# Module for handling a PostgreSQL database.

our @ISA = ("Codestriker::DB::Database");

# Type mappings.
my $_TYPE = {
    $Codestriker::DB::Column::TYPE->{TEXT}	=> "text",
    $Codestriker::DB::Column::TYPE->{VARCHAR}	=> "varchar",
    $Codestriker::DB::Column::TYPE->{INT32}	=> "int",
    $Codestriker::DB::Column::TYPE->{INT16}	=> "smallint",
    $Codestriker::DB::Column::TYPE->{DATETIME}	=> "timestamp",
    $Codestriker::DB::Column::TYPE->{FLOAT}	=> "float"
};

# Create a new PostgreSQL database object.
sub new {
    my $type = shift;
    
    # Database is parent class.
    my $self = Codestriker::DB::Database->new();
    $self->{sequence_created} = 0;
    return bless $self, $type;
}

# Return the DBD module this is dependent on.
sub get_module_dependencies {
    return { name => 'DBD::Pg', version => '0' };
}

sub getDBDModuleVer {
}

# Retrieve a database connection.
sub get_connection {
    my $self = shift;

    # PostgreSQL supports transactions, don't enable auto_commit.
    return $self->_get_connection(0, 1);
}

# Return the mapping for a specific type.
sub _map_type {
    my ($self, $type) = @_;
    return $_TYPE->{$type};
}

# Autoincrement type, which is based off a sequence.
sub _get_autoincrement_type {
    return "default nextval('sequence')";
}

# Create the table in the database for the specified table, and with the
# provided type mappings.
sub create_table {
    my ($self, $table) = @_;

    # Make sure the sequence is present in the database for autoincrement
    # fields.
    if ($self->{sequence_created} == 0) {
	my $dbh = $self->{dbh};

	eval {
	    $dbh->{PrintError} = 0;

	    $dbh->do("CREATE SEQUENCE sequence");
	    print "Created sequence\n";
	    $self->commit();
	};
	if ($@) {
	    eval { $self->rollback() };
	}

	$dbh->{PrintError} = 1;
	$self->{sequence_created} = 1;
    }

    # Now let the base class actually do the work in creating the table.
    $self->SUPER::create_table($table);
}

# Indicate if the LIKE operator can be applied on a "text" field.
# For PostgreSQL, this is true.
sub has_like_operator_for_text_field {
    my $self = shift;
    return 1;
}

# Function for generating an SQL subexpression for a case insensitive LIKE
# operation.
sub case_insensitive_like {
    my ($self, $field, $expression) = @_;

    $expression = $self->{dbh}->quote($expression);
    
    # Use the ILIKE operator.
    return "$field ILIKE $expression";
}

1;

	

