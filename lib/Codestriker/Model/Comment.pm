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
    my ($type, $topicid, $line, $email, $data, $timestamp, $state,
	$filename, $fileline) = @_;
    
    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Create the prepared statements.
    my $insert_comment =
	$dbh->prepare_cached('INSERT INTO comment (topicid, commentfield, ' .
			     'author, line, creation_ts) VALUES ' .
			     '(?, ?, ?, ?, ?)');
    my $success = defined $insert_comment;

    # Create the comment row.
    $success &&= $insert_comment->execute($topicid, $data, $email, $line,
					  $timestamp);

    # Check what the current version of this commentstate is, if any.
    my $select_ver = $dbh->prepare_cached('SELECT version FROM commentstate ' .
					  'WHERE topicid = ? AND line = ?');
    $success &&= defined $select_ver;
    $success &&= $select_ver->execute($topicid, $line);
    if ($success) {
	my ($version) = $select_ver->fetchrow_array();
	$success &&= $select_ver->finish();
	if (! defined $version) {
	    # Create the associated commentstate row.
	    my $insert = $dbh->prepare_cached('INSERT INTO commentstate ' .
					      '(topicid, line, state, ' .
					      'filename, fileline, version) ' .
					      'VALUES (?, ?, ?, ?, ?, ?)');
	    $success &&= defined $insert;
	    $success &&= $insert->execute($topicid, $line,
					  $Codestriker::COMMENT_SUBMITTED,
					  $filename, $fileline, 0);
	    $success &&= $insert->finish();
	} else {
	    # Update the comment state record.
	    my $update = $dbh->prepare_cached('UPDATE commentstate SET ' .
					      'version = ?, state = ? ' .
					      'WHERE topicid = ? ' .
					      'AND line = ?');
	    $success &&= defined $update;
	    $success &&= $update->execute($version+1,
					  $Codestriker::COMMENT_SUBMITTED,
					  $topicid, $line);
	    $success &&= $update->finish();
	}
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr if !$success;
}

# Read all of the comments made for a specified topic, and store the results
# in the passed-in references.
sub read($$\@\%) {
    my ($type, $topicid, $commentarray_ref, $existshash_ref) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Retrieve all of the comment information for the specified topicid.
    my $select_comment =
	$dbh->prepare_cached('SELECT comment.commentfield, comment.author, ' .
			     'comment.line, comment.creation_ts, ' .
			     'commentstate.state, commentstate.filename, ' .
			     'commentstate.fileline, commentstate.version ' .
			     'FROM comment, commentstate ' .
			     'WHERE comment.topicid = ? ' .
			     'AND commentstate.topicid = comment.topicid ' .
			     'AND commentstate.line = comment.line '.
			     'ORDER BY comment.line, comment.creation_ts');
    my $success = defined $select_comment;
    my $rc = $Codestriker::OK;
    $success &&= $select_comment->execute($topicid);

    # Store the results into the referenced arrays.
    if ($success) {
	my @data;
	while (@data = $select_comment->fetchrow_array()) {
	    my $comment = {};
	    $comment->{'data'} = $data[0];
	    $comment->{'author'} = $data[1];
	    $comment->{'line'} = $data[2];
	    $comment->{'date'} = Codestriker->format_timestamp($data[3]);
	    $comment->{'state'} = $data[4];
	    $comment->{'filename'} = $data[5];
	    $comment->{'fileline'} = $data[6];
	    $comment->{'version'} = $data[7];
	    push @$commentarray_ref, $comment;
	    $$existshash_ref{$data[2]} = 1;
	}
	$select_comment->finish();
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    return $rc;
}

# Update the state of the specified commentstate.  The version parameter
# indicates what version of the commentstate the user was operating on.
sub change_state($$$$$) {
    my ($type, $topicid, $line, $stateid, $version) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Check that the version reflects the current version in the DB.
    my $select_comments =
	$dbh->prepare_cached('SELECT version, state FROM commentstate ' .
			     'WHERE topicid = ? AND line = ?');
    my $update_comments =
	$dbh->prepare_cached('UPDATE commentstate SET version = ?, ' .
			     'state = ? WHERE topicid = ? AND line = ?');

    my $success = defined $select_comments && defined $update_comments;
    my $rc = $Codestriker::OK;

    # Retrieve the current comment data.
    $success &&= $select_comments->execute($topicid, $line);

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
					       $topicid, $line);
    }
    Codestriker::DB::DBI->release_connection($dbh, $success);
    return $rc;
}

1;
