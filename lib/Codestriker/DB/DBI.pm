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
use DBI;
use Codestriker;

# Retrieve a connection to the codestriker database.
sub get_connection($) {
    my ($type) = @_;

    # The latest versions of MySQL do support transaction control, but for
    # now its easiest to disable it.  Would be nice to know how to do this in
    # a better fashion.
    my $autocommit = ($Codestriker::db =~ /^DBI:mysql/) ? 1 : 0;

    return DBI->connect($Codestriker::db, $Codestriker::dbuser,
			$Codestriker::dbpasswd,
			{AutoCommit=>$autocommit, RaiseError=>1})
	|| die "Couldn't connect to database: " . DBI->errstr;
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
	    
    $connection->disconnect;
}

1;
