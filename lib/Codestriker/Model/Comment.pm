###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling comment data.

package Codestriker::Model::Comment;

use strict;

use Codestriker::DB::DBI;

# Create a new comment with all of the specified properties.  Ensure that the
# associated commentstate record is created/updated.
sub create($$$$$$$$$) {
    my ($type, $topicid, $fileline, $filenumber, $filenew, $email, $data,
	$timestamp, $state) = @_;
    
    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Check if a comment has been made against this line before.
    my $select_commentstate =
	$dbh->prepare_cached('SELECT version, id ' .
			     'FROM commentstate ' .
			     'WHERE topicid = ? AND fileline = ? AND '.
			     'filenumber = ? AND filenew = ?');
    my $success = defined $select_commentstate;
    $success &&= $select_commentstate->execute($topicid, $fileline,
					       $filenumber, $filenew);
    if ($success) {
	my ($version, $commentstateid) =
	    $select_commentstate->fetchrow_array();
	$success &&= $select_commentstate->finish();
	if (! defined $version) {
	    # A comment has not been made on this particular line yet,
	    # create the commentstate row now.
	    my $insert = $dbh->prepare_cached('INSERT INTO commentstate ' .
					      '(topicid, fileline, ' .
					      'filenumber, filenew, state, ' .
					      'version, creation_ts, ' .
					      'modified_ts) VALUES ' .
					      '(?, ?, ?, ?, ?, ?, ? ,?)');
	    $success &&= defined $insert;
	    $success &&= $insert->execute($topicid, $fileline, $filenumber,
					  $filenew,
					  $Codestriker::COMMENT_SUBMITTED, 0,
					  $timestamp, $timestamp);
	    $success &&= $insert->finish();
	} else {
	    # Update the commentstate record.
	    my $update = $dbh->prepare_cached('UPDATE commentstate SET ' .
					      'version = ?, state = ?, ' .
					      'modified_ts = ? ' .
					      'WHERE topicid = ? AND ' .
					      'fileline = ? AND ' .
					      'filenumber = ? AND ' .
					      'filenew = ?');
	    $success &&= defined $update;
	    $success &&= $update->execute($version+1,
					  $Codestriker::COMMENT_SUBMITTED,
					  $timestamp,
					  $topicid, $fileline, $filenumber,
					  $filenew);
	    $success &&= $update->finish();
	}

	# Determine the commentstateid that may have been just created.
	$success &&= $select_commentstate->execute($topicid, $fileline,
						   $filenumber, $filenew);
	if ($success) {
	    ($version, $commentstateid) = 
		$select_commentstate->fetchrow_array();
	}
	$success &&= $select_commentstate->finish();
	
	# Create the comment record.
	my $insert_comment =
	    $dbh->prepare_cached('INSERT INTO comment ' .
				 '(commentstateid, '.
				 'commentfield, author, creation_ts) ' .
				 'VALUES (?, ?, ?, ?)');
	my $success = defined $insert_comment;

	# Create the comment row.
	$success &&= $insert_comment->execute($commentstateid, $data,
					      $email, $timestamp);
	$success &&= $insert_comment->finish();

    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr if !$success;
}

# Return all of the comments made for a specified topic.
sub read($$) {
    my ($type, $topicid) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Store the results into an array of objects.
    my @results = ();

    # Retrieve all of the comment information for the specified topicid.
    my $select_comment =
	$dbh->prepare_cached('SELECT comment.commentfield, ' .
			     'comment.author, ' .
			     'commentstate.fileline, ' .
			     'commentstate.filenumber, ' .
			     'commentstate.filenew, ' .
			     'comment.creation_ts, ' .
			     'commentstate.state, ' .
			     'file.filename, ' .
			     'commentstate.version ' .
			     'FROM comment, commentstate, file ' .
			     'WHERE commentstate.topicid = ? ' .
			     'AND commentstate.id = comment.commentstateid ' .
			     'AND file.topicid = commentstate.topicid AND ' .
			     'file.sequence = commentstate.filenumber ' .
			     'ORDER BY ' .
			     'commentstate.filenumber, ' .
			     'commentstate.fileline, ' .
			     'comment.creation_ts');
    my $success = defined $select_comment;
    my $rc = $Codestriker::OK;
    $success &&= $select_comment->execute($topicid);

    # Store the results into the referenced arrays.
    if ($success) {
	my @data;
	while (@data = $select_comment->fetchrow_array()) {
	    my $comment = {};
	    $comment->{data} = $data[0];
	    $comment->{author} = $data[1];
	    $comment->{fileline} = $data[2];
	    $comment->{filenumber} = $data[3];
	    $comment->{filenew} = $data[4];
	    $comment->{date} = Codestriker->format_timestamp($data[5]);
	    $comment->{state} = $data[6];
	    $comment->{filename} = $data[7];
	    $comment->{version} = $data[8];
	    push @results, $comment;
	}
	$select_comment->finish();
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;

    return @results;
}

# Update the state of the specified commentstate.  The version parameter
# indicates what version of the commentstate the user was operating on.
sub change_state($$$$$$$) {
    my ($type, $topicid, $fileline, $filenumber, $filenew,
	$stateid, $version) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Check that the version reflects the current version in the DB.
    my $select_comments =
	$dbh->prepare_cached('SELECT version, state FROM commentstate ' .
			     'WHERE topicid = ? AND fileline = ? AND ' .
			     'filenumber = ? AND filenew = ?');
    my $update_comments =
	$dbh->prepare_cached('UPDATE commentstate SET version = ?, ' .
			     'state = ? WHERE topicid = ? AND fileline = ? ' .
			     'AND filenumber = ? AND filenew = ?');

    my $success = defined $select_comments && defined $update_comments;
    my $rc = $Codestriker::OK;

    # Retrieve the current comment data.
    $success &&= $select_comments->execute($topicid, $fileline, $filenumber,
					   $filenew);

    # Make sure that the topic still exists, and is therefore valid.
    my ($current_version, $current_stateid);
    if ($success && 
	! (($current_version, $current_stateid)
	   = $select_comments->fetchrow_array())) {
	# Invalid topic id.
	$success = 0;
	$rc = $Codestriker::INVALID_TOPIC;
    }
    $success &&= $select_comments->finish();

    # Check the version number.
    if ($success && $version != $current_version) {
	$success = 0;
	$rc = $Codestriker::STALE_VERSION;
    }

    # If the state hasn't changed, don't do anything, otherwise update the
    # comments.
    if ($stateid != $current_stateid) {
	$success &&= $update_comments->execute($version+1, $stateid,
					       $topicid, $fileline,
					       $filenumber, $filenew);
    }
    Codestriker::DB::DBI->release_connection($dbh, $success);
    return $rc;
}

1;
