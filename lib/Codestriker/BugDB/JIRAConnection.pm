###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# JIRA connection class, for appending comments to a bug report.

package Codestriker::BugDB::JIRAConnection;

use strict;
use DBI;

# Optional dependenct for people who don't use this module.
eval("use JIRA::Client;");

# Static method for building a database connection.
sub get_connection($) {
    my ($type) = @_;

    # Return a connection with JIRA.
    my $self = {};
    $self->{jira} = JIRA::Client->new($Codestriker::jira_url, $Codestriker::jira_username,
                                      $Codestriker::jira_password);
    bless $self, $type;
}

# Method for releasing a mantis database connection.
sub release_connection($) {
    my ($self) = @_;
}

# Return true if the specified bugid exists in the bug database,
# false otherwise.
sub bugid_exists($$) {
    my ($self, $bugid) = @_;

    return defined $self->{jira}->getIssue($bugid);
}

sub update_bug($$$$$) {

    my ($self, $bugid, $comment, $topic_url, $topic_state) = @_;

    # Insert the note: "Codestriker topic: Author: Reviewer(s): Title: Description: "
    $self->{jira}->addComment($bugid, $comment);
}

1;
