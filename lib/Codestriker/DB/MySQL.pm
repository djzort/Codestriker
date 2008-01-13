###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

package Codestriker::DB::MySQL;

use strict;
use DBI;
use Codestriker;
use Codestriker::DB::Database;

# Module for handling a MySQL database.

@Codestriker::DB::MySQL::ISA = ("Codestriker::DB::Database");

# Type mappings.
my $_TYPE = {
    $Codestriker::DB::Column::TYPE->{TEXT}	=> "longtext",
    $Codestriker::DB::Column::TYPE->{VARCHAR}	=> "varchar",
    $Codestriker::DB::Column::TYPE->{INT32}	=> "int",
    $Codestriker::DB::Column::TYPE->{INT16}	=> "smallint",
    $Codestriker::DB::Column::TYPE->{DATETIME}	=> "datetime",
    $Codestriker::DB::Column::TYPE->{FLOAT}	=> "float"
};

# Create a new MySQL database object.
sub new {
    my $type = shift;
    
    # Database is parent class.
    my $self = Codestriker::DB::Database->new();
    return bless $self, $type;
}

# Return the DBD module this is dependent on.
sub get_module_dependencies {
    return { name => 'DBD::mysql', version => '0' };
}

# Retrieve a database connection.
sub get_connection {
    my $self = shift;

    # Not all versions of MySQL upport transactions.  Its easiest for now to
    # just enable AUTO_COMMIT.
    my $dbh = $self->_get_connection(1, 1);

    # Older MySQL 3.X installations don't support these commands.  Wrap them
    # for now in a block and silently ignore the errors.
    {
	local $dbh->{RaiseError};
	local $dbh->{PrintError};
	$dbh->do("SET NAMES 'utf8'");
	$dbh->do("SET character_set_results='utf8'");
    }
    $dbh->do("SET max_allowed_packet=128000000");
    return $dbh;
}

# Return the mapping for a specific type.
sub _map_type {
    my ($self, $type) = @_;
    return $_TYPE->{$type};
}    

# Autoincrement type for MySQL.
sub _get_autoincrement_type {
    return "auto_increment";
}

# MySQL specific function adapted from Bugzilla.
sub get_field_def {
    my ($self, $table, $field) = @_;
    my $sth = $self->{dbh}->prepare("SHOW COLUMNS FROM $table");
    $sth->execute;
    
    while (my $ref = $sth->fetchrow_arrayref) {
        next if $$ref[0] ne $field;
        return $ref;
    }
}

# Indicate if the LIKE operator can be applied on a "text" field.
# For MySQL, this is true.
sub has_like_operator_for_text_field {
    my $self = shift;
    return 1;
}

# Function for generating an SQL subexpression for a case insensitive LIKE
# operation.
sub case_insensitive_like {
    my ($self, $field, $expression) = @_;
    
    $expression = $self->{dbh}->quote($expression);

    # MySQL is case insensitive by default, no need to do anything.
    return "$field LIKE $expression";
}


# These are no-ops for MySQL.
sub commit {}
sub rollback {}

1;

