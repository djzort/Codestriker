###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Bugzilla connection class, for appending comments to a bug report.

package Codestriker::BugDB::BugzillaConnection;

use strict;
use DBI;

# Static method for building a database connection.
sub get_connection($) {
    my ($type) = @_;

    # Return a connection with the bugzilla database.
    my $self = {};
    my $dbname = $Codestriker::bug_db_dbname;
    $dbname = "bugs" if ($dbname eq "");
    $self->{dbh} =
	DBI->connect("DBI:mysql:dbname=$dbname;host=$Codestriker::bug_db_host",
		     $Codestriker::bug_db_name, $Codestriker::bug_db_password,
		     { RaiseError => 1, AutoCommit => 1 });
    bless $self, $type;
}

# Method for releasing a bugzilla database connection.
sub release_connection($) {
    my ($self) = @_;
    
    $self->{dbh}->disconnect;
}

# Return true if the specified bugid exists in the bug database,
# false otherwise.
sub bugid_exists($$) {
    my ($self, $bugid) = @_;

    return $self->{dbh}->selectrow_array('SELECT COUNT(*) FROM bugs ' .
					 'WHERE bug_id = ?', {}, $bugid) != 0;
}

# Method for updating the bug with information that a code review has been
# created/closed/committed against this bug.
sub update_bug($$$$$) {
    my ($self, $bugid, $comment, $topic_url, $topic_state) = @_;

    # Create the necessary prepared statements.
    my $insert_comment =
	$self->{dbh}->prepare_cached('INSERT INTO longdescs ' .
				     '(bug_id, who, bug_when, thetext) ' .
				     'VALUES (?, ?, now(), ?)');
    my $update_bug =
	$self->{dbh}->prepare_cached('UPDATE bugs SET delta_ts = now() ' .
				     'WHERE bug_id = ?');

    # Execute the statements.
    $insert_comment->execute($bugid, $Codestriker::bug_db_user_id, $comment);
    $update_bug->execute($bugid);
}

1;
