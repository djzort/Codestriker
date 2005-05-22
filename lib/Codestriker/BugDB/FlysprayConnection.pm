###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Flyspray connection class, for appending comments to a bug report.

package Codestriker::BugDB::FlysprayConnection;

use strict;
use DBI;

# Static method for building a database connection.
sub get_connection($) {
    my ($type) = @_;

    # Return a connection with the flyspray database.
    my $self = {};
    my $dbname = $Codestriker::flyspray_db_dbname;
    $dbname = "flyspray" if ($dbname eq "");
    $self->{dbh} =
	DBI->connect("DBI:mysql:dbname=$dbname;host=$Codestriker::flyspray_db_host",
		     $Codestriker::flyspray_db_name, $Codestriker::flyspray_db_password,
		     { RaiseError => 1, AutoCommit => 1 });
    bless $self, $type;
}

# Method for releasing a flyspray database connection.
sub release_connection($) {
    my ($self) = @_;
    
    $self->{dbh}->disconnect;
}

# Method for updating the bug with information that a code review has been
# created/closed/committed against this bug.
sub update_bug($$$$) {
    my ($self, $bugid, $comment) = @_;

    # Create the necessary prepared statements.
    my $insert_comment =
	$self->{dbh}->prepare_cached('INSERT INTO flyspray_comments ' .
				     '(task_id, user_id, date_added, comment_text) ' .
				     'VALUES (?, ?, ?, ?)');
    my $insert_history =
	$self->{dbh}->prepare_cached('INSERT INTO flyspray_history ' .
				     '(task_id, user_id, event_date, event_type, new_value) ' .
				     'VALUES (?, ?, ?, 4, 1)');

    # Execute the statement.

    $comment =~ s/(http:\S+)/<A HREF=\"$1\">$1<\/A>/g;
    $insert_comment->execute($bugid, $Codestriker::bug_db_user_id, time(), $comment) or die $insert_comment->errstr;
    $insert_history->execute($bugid, $Codestriker::bug_db_user_id, time()) or die $insert_history->errstr;
}

1;
