###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

package Codestriker::DB::Oracle;

use strict;
use DBI;
use Codestriker;
use Codestriker::DB::Database;

# Module for handling an Oracle database.

@Codestriker::DB::Oracle::ISA = ("Codestriker::DB::Database");

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
    $self->{sequence_created} = 0;
    return bless $self, $type;
}

# Return the DBD module this is dependent on.
sub get_module_dependencies {
    return { name => 'DBD::Oracle', version => '0' };
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

    # Make sure the sequence is present in the database for the trigger to
    # work.
    eval {
	if ($self->{sequence_created} == 0) {

	    $dbh->do("CREATE SEQUENCE sequence");
	    print "Created sequence\n";
	    $self->{sequence_created} = 1;
	}

	# Now create the actual trigger on the table.
	$dbh->do("CREATE TRIGGER ${tablename}_${fieldname}_ins_row " .
		 "BEFORE INSERT ON ${tablename} FOR EACH ROW " .
		 "DECLARE newid integer; " .
		 "BEGIN " .
		 "IF (:NEW.${fieldname} IS NULL) " .
		 "THEN " .
		 "SELECT sequence.NextVal INTO newid FROM DUAL; " .
		 ":NEW.${fieldname} := newid; " .
		 "END IF; " .
		 "END;");
	print "Created trigger\n";
	$dbh->commit();
    };
    if ($@) {
	eval { $self->rollback() };
	die "Unable to create sequence/trigger.\n";
    }
}

# Add a field to a specific table.  If the field already exists, then catch
# the error and continue silently.  The SYNTAX for SQL Server is slightly
# different to standard SQL, there is no "COLUMN" keyword after "ADD".
sub add_field {
    my ($self, $table, $field, $definition) = @_;

    my $dbh = $self->{dbh};
    my $rc = 0;

    eval {
	$dbh->{PrintError} = 0;
	my $field_type = $self->_map_type($definition);

	$dbh->do("ALTER TABLE $table ADD $field $field_type");
	print "Added new field $field to table $table.\n";
	$rc = 1;
	$self->commit();
    };
    if ($@) {
	eval { $self->rollback() };
    }
    
    $dbh->{PrintError} = 1;

    return $rc;
}

# Indicate if the LIKE operator can be applied on a "text" field.
# For Oracle, this is false.
sub has_like_operator_for_text_field {
    my $self = shift;
    return 0;
}

# Function for generating an SQL subexpression for a case insensitive LIKE
# operation.
sub case_insensitive_like {
    my ($self, $field, $expression) = @_;
    
    # Convert the field and expression to lower case to get case insensitivity.
    my $field_lower = "lower($field)";
    my $expression_lower = $expression;
    $expression_lower =~ tr/[A-Z]/[a-z]/;
    $expression_lower = $self->{dbh}->quote($expression_lower);

    return "$field_lower LIKE $expression_lower";
}

1;

