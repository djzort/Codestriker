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

    return DBI->connect($Codestriker::db, $Codestriker::dbuser,
			$Codestriker::dbpasswd, {AutoCommit=>0, RaiseError=>1})
	|| die "Couldn't connect to database: " . DBI->errstr;
}

# Release a connection.
sub release_connection($$) {
    my ($type, $connection) = @_;

    $connection->disconnect;
}

1;
