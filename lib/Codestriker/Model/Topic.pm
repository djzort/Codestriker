###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling topic data.

package Codestriker::Model::Topic;

use strict;
use CGI::Carp 'fatalsToBrowser';

use Codestriker::DB::DBI;
use Codestriker::Model::File;

# Participant type constants.
my $PARTICIPANT_REVIEWER = 0;
my $PARTICIPANT_CC = 1;

# Topic state constants.
my $STATE_OPEN = 0;
my $STATE_ACCEPTED = 1;
my $STATE_REJECTED = 2;
my $STATE_COMMITTED = 3;

# Create a new topic with all of the specified properties.
sub create($$$$$$$$$) {
    my ($type, $topicid, $author, $title, $bug_ids, $reviewers, $cc,
	$description, $document) = @_;
    
    my @bug_ids = split /, /, $bug_ids;
    my @reviewers = split /, /, $reviewers;
    my @cc = split /, /, $cc;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Create the prepared statements.
    my $insert_topic =
	$dbh->prepare_cached('INSERT INTO TOPIC (id, author, title, ' .
			     'description, document, state, creation_ts, '.
			     'modified_ts) VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
    my $insert_bugs =
	$dbh->prepare_cached('INSERT INTO TOPICBUG (topicid, bugid) ' .
			     'VALUES (?, ?)');
    my $insert_participant =
	$dbh->prepare_cached('INSERT INTO PARTICIPANT (email, topicid, type,' .
			     'state, modified_ts) VALUES (?, ?, ?, ?, ?)');

    die "Could not create prepared statement: " . $dbh->errstr
	unless defined $insert_topic && defined $insert_bugs &&
	defined $insert_participant;

    my $success = 1;

    # Create all of the necessary rows.
    my $timestamp = Codestriker->get_current_timestamp();
    $success &&= $insert_topic->execute($topicid, $author, $title,
					$description, $document, $STATE_OPEN,
					$timestamp, $timestamp);
					
    for (my $i = 0; $i <= $#bug_ids; $i++) {
	$success &&= $insert_bugs->execute($topicid, $bug_ids[$i]);
    }

    for (my $i = 0; $i <= $#reviewers; $i++) {
	$success &&= $insert_participant->execute($reviewers[$i], $topicid,
						  $PARTICIPANT_REVIEWER, 0,
						  $timestamp);
    }
    
    for (my $i = 0; $i <= $#cc; $i++) {
	$success &&= $insert_participant->execute($cc[$i], $topicid,
						  $PARTICIPANT_CC, 0,
						  $timestamp);
    }

    # Create the appropriate file rows, if we diff file is being reviewed.
    $success &&= Codestriker::Model::File->create($dbh, $topicid, $document);
    
    my $result = ($success ? $dbh->commit : $dbh->rollback);
    die "Couldn't finish transaction" unless $result;

    return $success;
}

# Read the contents of a specific topic, and return the results in the
# provided reference variables.
sub read($$\$\$\$\$\$\$\$\$\$) {
    my ($type, $topicid, $author_ref, $title_ref, $bug_ids_ref, $reviewers_ref,
	$cc_ref, $description_ref, $document_ref, $creation_time_ref,
	$modified_time_ref) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Retrieve the topic information.
    my $select_topic = $dbh->prepare_cached('SELECT id, author, title, ' .
					    'description, document, state, ' .
					    'creation_ts, modified_ts '.
					    'FROM topic WHERE id = ?')
	|| die "Failed to prepare statement: " . $dbh->errstr;
    $select_topic->execute($topicid)
	|| die "Couldn't execute statement: " . $dbh->errstr;
    my ($id, $author, $title, $description, $document, $state, $creationtime,
	$modifiedtime) = $select_topic->fetchrow_array();

    # Retrieve the bug relating to this topic.
    my @bugs = ();
    my $select_bugs =
	$dbh->prepare_cached('SELECT bugid FROM topicbug WHERE topicid = ?');
    $select_bugs->execute($topicid) ||
	die "Couldn't execute statement: " . $dbh->errstr;
    my @data;
    while (@data = $select_bugs->fetchrow_array()) {
	push @bugs, $data[0];
    }

    # Retrieve the participants in this review.
    my @reviewers = ();
    my @cc = ();
    my $select_participants =
	$dbh->prepare_cached('SELECT type, email FROM participant ' .
			     'WHERE topicid = ?');
    $select_participants->execute($topicid) ||
	die "Couldn't execute statement: " . $dbh->errstr;
    while (@data = $select_participants->fetchrow_array()) {
	if ($data[0] == 0) {
	    push @reviewers, $data[1];
	} else {
	    push @cc, $data[1];
	}
    }

    # Store the data into the referenced variables.
    $$author_ref = $author;
    $$title_ref = $title;
    $$bug_ids_ref = join ', ', @bugs;
    $$reviewers_ref = join ', ', @reviewers;
    $$cc_ref = join ', ', @cc;
    $$description_ref = $description;
    $$document_ref = $document;
    $$creation_time_ref = Codestriker->format_timestamp($creationtime);
    $$modified_time_ref = Codestriker->format_timestamp($modifiedtime);
}

# Determine if the specified topic id exists in the table or not.
sub exists($$) {
    my ($type, $topicid) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Prepare the statement.
    my $select_topic = $dbh->prepare_cached('SELECT COUNT(*) FROM topic ' .
					    'WHERE id = ?')
	|| die "Failed to prepare statement: " . $dbh->errstr;

    # Execute it, and return the result.
    $select_topic->execute($topicid)
	|| die "Failed to execute statement: " . $dbh->errstr;

    my ($count) = $select_topic->fetchrow_array();
    return $count;
}

1;
