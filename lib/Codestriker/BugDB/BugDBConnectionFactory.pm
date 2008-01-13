###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Factory class for retrieving a bug database connection.

package Codestriker::BugDB::BugDBConnectionFactory;

use strict;
use Codestriker::BugDB::BugzillaConnection;
use Codestriker::BugDB::FlysprayConnection;
use Codestriker::BugDB::NoConnection;
use Codestriker::BugDB::TestDirectorConnection;

# Factory method for retrieving a BugDBConnection object.
sub getBugDBConnection ($) {
    my ($type) = @_;

    my $dbtype = $Codestriker::bug_db;
    if ($dbtype eq "bugzilla") {
	return Codestriker::BugDB::BugzillaConnection->get_connection();
    } elsif ($dbtype eq "flyspray") {
	return Codestriker::BugDB::FlysprayConnection->get_connection();
    } elsif ($dbtype eq "testdirector") {
	return Codestriker::BugDB::TestDirectorConnection->get_connection();
    } elsif ($dbtype =~ /^noconnect/) {
	return Codestriker::BugDB::NoConnection->get_connection();
    } else {
	die "Unsupported bug database type: $dbtype";
    }
}

1;
