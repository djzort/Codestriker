###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

package Codestriker::DB::Database;

use strict;

use DBI;
use Codestriker;
use Codestriker::DB::Column;
use Codestriker::DB::Index;
use Codestriker::DB::PostgreSQL;
use Codestriker::DB::MySQL;
use Codestriker::DB::Oracle;
use Codestriker::DB::ODBC;
use Codestriker::DB::SQLite;

# Print out creation statements before executing them if this is true.
my $_DEBUG = 0;

# Base object for all database objects.
sub new {
    my $type = shift;
    my $self = {};
    return bless $self, $type;
}

# Factory object for retrieving a database object based on what is set
# in the configuration.
sub get_database {
    my $type = shift;

    if ($Codestriker::db =~ /^DBI:mysql/i) {
	return Codestriker::DB::MySQL->new();
    } elsif ($Codestriker::db =~ /^DBI:Pg/i) {
	return Codestriker::DB::PostgreSQL->new($Codestriker::db);
    } elsif ($Codestriker::db =~ /^DBI:Odbc/i) {
	return Codestriker::DB::ODBC->new();
    } elsif ($Codestriker::db =~ /^DBI:Oracle/i) {
	return Codestriker::DB::Oracle->new();
    } elsif ($Codestriker::db =~ /^DBI:SQLite/i) {
	return Codestriker::DB::SQLite->new();
    } else {
	die "Unsupported database type: $Codestriker::db\n";
    }
}

# Create a new database connection with the specified auto_commit and
# raise_error properties.  If an active connection is already associated
# with the database, return that.
sub _get_connection {
    my ($self, $auto_commit, $raise_error) = @_;

    # If a connection has already been created, return it.
    return $self->{dbh} if (exists $self->{dbh});

    $self->{dbh} = DBI->connect($Codestriker::db, $Codestriker::dbuser,
				$Codestriker::dbpasswd,
				{AutoCommit=>$auto_commit,
				 RaiseError=>$raise_error,
				 LongReadLen=>10240000});

    # To see debugging from the DBI driver.
    # $self->{dbh}->{TraceLevel} = 1;

    # Return the new connection.
    return $self->{dbh};
}

# Release the connection associated with the database, and either commit or
# rollback it depending on the value of $commit.
sub release_connection {
    my ($self) = @_;

    # Check there is an active connection.
    if (! defined $self->{dbh}) {
	die "Cannot release connection on database as no active connection\n";
    }

    # Disconnect the connection.
    $self->{dbh}->disconnect();
    $self->{dbh} = undef;
}

# Create the table in the database for the specified table, and with the
# provided type mappings.
sub create_table {
    my ($self, $table) = @_;

    # Create the initial table entry.
    my $stmt = "CREATE TABLE " . $table->get_name() . "(\n";
    
    # For each column, add the appropriate statement.
    my @pk = ();
    my $first_column = 1;
    foreach my $column (@{$table->get_columns()}) {
	push @pk, $column->get_name() if $column->is_primarykey();

	# Add the comma for the start of the next field if necessary.
	if ($first_column) {
	    $first_column = 0;
	} else {
	    $stmt .= ",\n";
	}

	# Add in the basic field definition.
	$stmt .= $column->get_name() . " " .
	    $self->_map_type($column->get_type());

	# Check if the length constraint is required for a varchar expression.
	if ($column->get_type() == $Codestriker::DB::Column::TYPE->{VARCHAR}) {
	    $stmt .= "(" . $column->get_length() . ")";
	}

	# Add the "NOT NULL" constraint if the column is mandatory.
	$stmt .= " NOT NULL" if $column->is_mandatory();

	# Add any autoincrement field decorations if required.
	if ($column->is_autoincrement()) {
	    $stmt .= " " . $self->_get_autoincrement_type();
	}
    }

    # Now add in the primary definition if required.
    if (scalar(@pk) > 0) {
	$stmt .= ",\nPRIMARY KEY (" . (join ', ', @pk) . ")\n";
    }

    # Close off the statement.
    $stmt .= ")\n";

    print STDERR "Statement is: $stmt\n" if $_DEBUG;

    eval {
	# Now create the table.
	$self->{dbh}->do($stmt);

	# Now create the indexes for this table.
	foreach my $index (@{$table->get_indexes()}) {
	    my $index_stmt = "CREATE INDEX " . $index->get_name . " ON " .
		$table->get_name() . "(";
	    $index_stmt .= (join ', ', @{$index->get_column_names()}) . ")";
	    
	    print STDERR "Index statement is: $index_stmt\n" if $_DEBUG;
	    
	    # Now execute the statement to create the index.
	    $self->{dbh}->do($index_stmt);
	}

	# Commit the table creation.
	$self->commit();
    };
    if ($@) {
	eval { $self->rollback() };
	die "Unable to create table/indexes.\n";
    }
}

# Method for retrieving the list of current tables attached to the database.
# For most DBI implementations, this implementation works fine.
sub get_tables() {
    my $self = shift;

    # Remove any tables that end in a period, or have backticks.  Recent
    # versions of MySQL are now using backticks around the table name.
    my @tables = $self->{dbh}->tables;
    @tables = map { $_ =~ s/.*\.//; $_ } @tables;
    @tables = map { $_ =~ s/\`//g; $_ } @tables;
    
    return @tables;
}

# Add a field to a specific table.  If the field already exists, then catch
# the error and continue silently.
sub add_field {
    my ($self, $table, $field, $definition) = @_;

    my $dbh = $self->{dbh};
    my $rc = 0;

    eval {
	$dbh->{PrintError} = 0;
	my $field_type = $self->_map_type($definition);

	$dbh->do("ALTER TABLE $table ADD COLUMN $field $field_type");
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

# Check if the specified column exists in the specified table.
sub column_exists {
    my ($self, $tablename, $columnname) = @_;

    my $dbh = $self->{dbh};
    my $rc = 0;

    eval {
	$dbh->{PrintError} = 0;

	my $stmt = $dbh->prepare_cached("SELECT COUNT($columnname) " .
					"FROM $tablename");
	$rc = defined $stmt && $stmt->execute() ? 1 : 0;
	$stmt->finish();
	$self->commit();
    };
    if ($@) {
	eval { $self->rollback() };
    }

    $dbh->{PrintError} = 1;

    return $rc;
}

# Method for moving a database table to another name in a safe manner.
sub move_table {
    my ($self, $old_tablename, $new_tablename) = @_;

    my $dbh = $self->{dbh};
    my $rc = 0;

    eval {
	$dbh->{PrintError} = 0;

	my $stmt =
	    $dbh->prepare_cached("ALTER TABLE $old_tablename RENAME TO " .
				 "$new_tablename");
	my $rc = defined $stmt && $stmt->execute() ? 1 : 0;
	$stmt->finish() if (defined $stmt);
	$self->commit();
    };
    if ($@) {
	eval { $self->rollback() };
    }

    $dbh->{PrintError} = 1;

    return $rc;
}    

# Simple method for committing the current database transaction.
sub commit {
    my ($self) = @_;
    $self->{dbh}->commit();
}

# Simple method for rolling back the current database transaction.
sub rollback {
    my ($self) = @_;
    $self->{dbh}->rollback();
}

1;
