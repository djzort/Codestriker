###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

package Codestriker::DB::Oracle;

use strict;
use warnings;
use DBI;
use Codestriker;
use Codestriker::DB::Database;

# Module for handling an Oracle database.

our @ISA = ("Codestriker::DB::Database");

# Type mappings.
my $_TYPE = {
    $Codestriker::DB::Column::TYPE->{TEXT}	=> "clob",
    $Codestriker::DB::Column::TYPE->{VARCHAR}	=> "varchar2",
    $Codestriker::DB::Column::TYPE->{INT32}	=> "number(10)",
    $Codestriker::DB::Column::TYPE->{INT16}	=> "number(4)",
    $Codestriker::DB::Column::TYPE->{DATETIME}	=> "date",
    $Codestriker::DB::Column::TYPE->{FLOAT}	=> "float"
};

# Create a new Oracle database object.
sub new {
    my $type = shift;
    
    # Database is parent class.
    my $self = Codestriker::DB::Database->new();
    return bless $self, $type;
}

# Retrieve a database connection.
sub get_connection {
    my $self = shift;

    # Oracle support transactions, don't enable auto_commit.
    my $dbh = $self->_get_connection(0, 1);

    # Make sure the default date type is set to something used consistently
    # in Codestriker.
    $dbh->do("ALTER session SET NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS'");

    return $dbh;
}

# Method for retrieving the list of current tables attached to the database.
# For oracle, $dbh->tables doesn't work, need to retrieve data from the
# user_tabels table.
sub get_tables() {
    my $self = shift;

    my @tables = ();
    my $table_select =
	$self->{dbh}->prepare_cached("SELECT table_name FROM user_tables");
    $table_select->execute();
    while (my ($table_name) = $table_select->fetchrow_array()) {
	push @tables, $table_name;
    }
    $table_select->finish();

    return @tables;
}

# Return the mapping for a specific type.
sub _map_type {
    my ($self, $type) = @_;
    return $_TYPE->{$type};
}

# Oracle implements autoincrements with triggers.
sub _get_autoincrement_type {
    return "";
}

# Create the table in the database for the specified table, and with the
# provided type mappings.
sub create_table {
    my ($self, $table) = @_;

    # Let the base class actually do the work in creating the table.
    $self->SUPER::create_table($table);

    # Create the necessary triggers for any autoincrement fields.
    foreach my $column (@{$table->get_columns()}) {
	if ($column->is_autoincrement()) {
	    print "Creating autoincrement trigger for table: " .
		$table->get_name() . " field: " . $column->get_name() . "\n";
	    $self->_oracle_handle_auto_increment($table->get_name(),
						 $column->get_name());
	}
    }
}

# Oracle-specific routine for creating a trigger on a new row insert to
# automatically assign a value to the specified fieldname from a sequence.
# This is used since Oracle doesn't support auto-increment or default values
# for fields.
sub _oracle_handle_auto_increment
{
    my ($self, $tablename, $fieldname) = @_;

    my $dbh = $self->{dbh};

    $dbh->do("CREATE TRIGGER ${tablename}_${fieldname}_ins_row " .
	     "BEFORE INSERT ON ${tablename} FOR EACH ROW " .
	     "DECLARE newid integer; " .
	     "BEGIN " .
	     "IF (:NEW.${fieldname} IS NULL) " .
	     "THEN " .
	     "SELECT sequence.NextVal INTO newid FROM DUAL; " .
	     ":NEW.${fieldname} := newid; " .
	     "END IF; " .
	     "END;")
	|| die "Could not create trigger for table $tablename: " .
	$dbh->errstr;
}

1;

