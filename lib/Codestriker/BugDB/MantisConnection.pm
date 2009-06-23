###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Mantis connection class, for appending comments to a bug report.

package Codestriker::BugDB::MantisConnection;

use strict;
use DBI;

# Static method for building a database connection.
sub get_connection($) {
    my ($type) = @_;

    # Return a connection with the mantis database.
    my $self = {};
    my $dbname = $Codestriker::bug_db_dbname;
    $dbname = "bugs" if ($dbname eq "");
    $self->{dbh} =
      DBI->connect("DBI:mysql:dbname=$dbname;host=$Codestriker::bug_db_host",
                   $Codestriker::bug_db_name, $Codestriker::bug_db_password,
                   {
                    RaiseError => 1, AutoCommit => 1 });
    bless $self, $type;
}

# Method for releasing a mantis database connection.
sub release_connection($) {
    my ($self) = @_;

    $self->{dbh}->disconnect;
}

# Return true if the specified bugid exists in the bug database,
# false otherwise.
sub bugid_exists($$) {
    my ($self, $bugid) = @_;

    return $self->{dbh}->selectrow_array('SELECT COUNT(*) FROM mantis_bug_table ' .
                                         'WHERE bug_text_id = ?', {}, $bugid) != 0;
}

sub update_bug($$$$$) {

    my ($self, $bugid, $comment, $topic_url, $topic_state) = @_;
    
    my $time_tracking = '0:00';
    my $private = 'false';
    my $type = 0;
    my $attr = '';
    my $user_id = 'null';
    my $send_email = 'TRUE';
    my $view_state = 'VS_PUBLIC';

    # Insert the note: "Codestriker topic: Author: Reviewer(s): Title: Description: " 
    my $insert_comment =
      $self->{dbh}->prepare_cached('INSERT INTO mantis_bugnote_text_table ' . '( note ) ' . 'VALUES ( ? )');

    $insert_comment->execute($comment);

    # Retrieve bugnote text id number
    my $bugnote_text_id = $self->{dbh}->last_insert_id(undef, undef, "mantis_bugnote_text_table",
                                                       undef, [ Warn => 0]);

    # Update the bug(s)
    my $update_bug =
      $self->{dbh}->prepare_cached('INSERT INTO mantis_bugnote_table ' 
			     . '(bug_id, reporter_id, bugnote_text_id, view_state, date_submitted, last_modified, note_type, note_attr, time_tracking ) '
			     . 'VALUES (?, ?, ?, ?, now(), now(), ?, ?, ? )');

    $update_bug->execute($bugid, $Codestriker::bug_db_user_id, $bugnote_text_id, $view_state, $type, $attr, $time_tracking);
}

1;
