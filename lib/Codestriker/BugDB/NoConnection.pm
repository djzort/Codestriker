###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Connection class which actually doesn't connect to a real bug database.
# All methods are no-ops.

package Codestriker::BugDB::NoConnection;

use strict;
use DBI;

# Static method for building a database connection.
sub get_connection($) {
    my ($type) = @_;
    my $self = {};
    bless $self, $type;
}

# Method for releasing a database connection.
sub release_connection($) {
}

# Return true if the specified bugid exists in the bug database,
# false otherwise.
sub bugid_exists($$) {
    return 1;
}

# Method for updating the bug with information that a code review has been
# created/closed/committed against this bug.
sub update_bug($$$$) {
}

1;
