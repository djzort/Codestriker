###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Simple object used for retrieving and keeping a record of active DBI
# database connections.

package Codestriker::DB::DBI;

use strict;
use Codestriker;
use Codestriker::DB::Database;

# DBI connections are expensive to make, only have one per process, and when 
# the code asks for a connection, just keep returning the same one.
our $connection;

# Retrieve a connection to the codestriker database for the specified
sub get_connection($) {
    my ($type) = @_;

    # Making a connection is expensive, cache it.
    if ( !defined($connection) ) {
	my $database = Codestriker::DB::Database->get_database();

        $connection = $database->get_connection();
    }

    return $connection;
}

# Release a connection, and if $success is true and this is a transaction
# controlled database, commit the transaction, otherwise abort it.
sub release_connection($$$) {
    my ($type, $connection, $success) = @_;

    # If the connection is transaction controlled, commit or abort the
    # transaction depending on the value of $success.
    if ($connection->{AutoCommit} == 0) {
	$success ? $connection->commit : $connection->rollback;
    }
}

1;
