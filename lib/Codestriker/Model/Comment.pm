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

sub new {
    my $class = shift;
    my $self = {};

    $self->{id} = 0;
    $self->{topicid} = 0;
    $self->{fileline} = 0;
    $self->{filenumber} = 0;
    $self->{filenew} = 0;
    $self->{author} = '';
    $self->{data} = '';
    $self->{date} = Codestriker->get_timestamp(time);
    $self->{state} = 0;
    $self->{version} = 0;
    $self->{creation_ts} = "";
    $self->{modified_ts} = "";
    
    bless $self, $class;
    return $self;
}

# Create a new comment with all of the specified properties.  Ensure that the
# associated commentstate record is created/updated.
sub create($$$$$$$$$) {
    my ($self, $topicid, $fileline, $filenumber, $filenew, $author, $data,
	$state) = @_;
            
    my $timestamp = Codestriker->get_timestamp(time);
    
    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Check if a comment has been made against this line before.
    my $select_commentstate =
	$dbh->prepare_cached('SELECT version, id, creation_ts ' .
			     'FROM commentstate ' .
			     'WHERE topicid = ? AND fileline = ? AND '.
			     'filenumber = ? AND filenew = ?');
    my $success = defined $select_commentstate;
    $success &&= $select_commentstate->execute($topicid, $fileline,
					       $filenumber, $filenew);
    my $commentstateid = 0;
    my $version = 0;
    my $creation_ts = "";
    if ($success) {
	($version, $commentstateid, $creation_ts) =
	    $select_commentstate->fetchrow_array();
	$success &&= $select_commentstate->finish();
	if (! defined $version) {
	    # A comment has not been made on this particular line yet,
	    # create the commentstate row now.
	    $creation_ts = $timestamp;
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
					  $creation_ts, $creation_ts);
	    $success &&= $insert->finish();
	} else {
	    # Update the commentstate record.
	    my $update = $dbh->prepare_cached('UPDATE commentstate SET ' .
					      'version = ?, state = ?, ' .
					      'creation_ts = ?, ' .
					      'modified_ts = ? ' .
					      'WHERE topicid = ? AND ' .
					      'fileline = ? AND ' .
					      'filenumber = ? AND ' .
					      'filenew = ?');
	    $success &&= defined $update;
	    $success &&= $update->execute(++$version,
					  $Codestriker::COMMENT_SUBMITTED,
					  $creation_ts, $timestamp,
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
					      $author, $timestamp);
	$success &&= $insert_comment->finish();
    }

    $self->{id} = $commentstateid;
    $self->{topicid} =  $topicid;
    $self->{fileline} = $fileline;
    $self->{filenumber} = $filenumber;
    $self->{filenew} = $filenew;
    $self->{author} = $author;
    $self->{data} = $data;
    $self->{date} = $timestamp;
    $self->{state} = $state;
    $self->{version} = $version;
    $self->{creation_ts} = $creation_ts;
    $self->{modified_ts} = $timestamp;
        
    # get the filename, for the new comment.
    my $get_filename = $dbh->prepare_cached('SELECT filename ' .
					    'FROM topicfile ' .
					    'WHERE topicid = ? AND ' .
					    'sequence = ?');
    $success &&= defined $get_filename;
    $success &&= $get_filename->execute($topicid, $filenumber);
                
    ( $self->{filename} ) = $get_filename->fetchrow_array();
    
    $select_commentstate = undef;
    $get_filename = undef;

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr if !$success;
}

# This function returns as a list the authors emails address that have entered 
# comments against a topic.
sub read_authors
{
   my ($type, $topicid ) = @_;
   
    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Store the results into an array of objects.
    my @results;

    # Retrieve all of the comment information for the specified topicid.
    my $select_comment =
	$dbh->prepare_cached('SELECT distinct(comment.author) ' .
			     'FROM comment, commentstate ' .
			     'WHERE commentstate.topicid = ? ' .
			     'AND commentstate.id = comment.commentstateid ');
                             
    my $success = defined $select_comment;
    my $rc = $Codestriker::OK;
    $success &&= $select_comment->execute($topicid);

    # Store the results into the referenced arrays.
    if ($success) {
	my @data;
	while (@data = $select_comment->fetchrow_array()) {
	    push @results, $data[0];
	}
	$select_comment->finish();
    }
    
    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;

    return @results;   
}

# Return all of the comments made for a specified topic. This should only be called be called by the 
# Topic object.
sub read_all_comments_for_topic($$) {
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
			     'topicfile.filename, ' .
			     'commentstate.version, ' .
			     'commentstate.id, ' .
			     'commentstate.creation_ts, ' .
			     'commentstate.modified_ts ' .
			     'FROM comment, commentstate, topicfile ' .
			     'WHERE commentstate.topicid = ? ' .
			     'AND commentstate.id = comment.commentstateid ' .
			     'AND topicfile.topicid = commentstate.topicid ' .
			     'AND topicfile.sequence = commentstate.filenumber ' .
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
	    my $comment = Codestriker::Model::Comment->new();
	    $comment->{topicid} =  $topicid;            
	    $comment->{data} = $data[0];
	    $comment->{author} = $data[1];
	    $comment->{fileline} = $data[2];
	    $comment->{filenumber} = $data[3];
	    $comment->{filenew} = $data[4];
	    $comment->{date} = Codestriker->format_timestamp($data[5]);
	    $comment->{state} = $data[6];
	    $comment->{filename} = $data[7];
	    $comment->{version} = $data[8];
	    $comment->{id} = $data[9];
	    $comment->{creation_ts} = Codestriker->format_timestamp($data[10]);
	    $comment->{modified_ts} = Codestriker->format_timestamp($data[11]);
	    push @results, $comment;
	}
	$select_comment->finish();
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;

    return @results;
}

# Return all of the comments made for a specified topic filtered by state 
# and author. The filtered parameter is not used if it is empty.
sub read_filtered($$$$) {
    my ($type, $topicid, $filtered_by_state_index, $filtered_by_author) = @_;
    
    # Read all of the comments from the database. 
    my @comments = $type->read_all_comments_for_topic($topicid);

    # Now filter out comments that don't match the comment state and
    # author filter.
    @comments = grep { 
        my $comment = $_;
        my $keep_comment = 1;
                                
        # Check for filter via the state of the comment.
        $keep_comment = 0 if ($filtered_by_state_index ne ""  && 
			      $filtered_by_state_index ne $comment->{state} );
        
        # Check for filters via the comment author name, handle email
        # SPAM filtering.
        my $filteredAuthor =
            	    Codestriker->filter_email($comment->{author});
        my $filteredByAuthor =
            	    Codestriker->filter_email($filtered_by_author);

        $keep_comment = 0 if ($filteredByAuthor ne "" && 
			      $filteredAuthor ne $filteredByAuthor);

 	$keep_comment;
    } @comments;
    
    return @comments;
}

# Update the state of the specified commentstate.  The version parameter
# indicates what version of the commentstate the user was operating on.
sub change_state($$) {
    my ($self, $new_stateid, $version) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    my $timestamp = Codestriker->get_timestamp(time);   

    # Check that the version reflects the current version in the DB.
    my $select_comments =
	$dbh->prepare_cached('SELECT version, state, creation_ts ' .
			     'FROM commentstate ' .
			     'WHERE topicid = ? AND fileline = ? AND ' .
			     'filenumber = ? AND filenew = ?');
    my $update_comments =
	$dbh->prepare_cached('UPDATE commentstate SET version = ?, ' .
			     'state = ?, creation_ts = ?, modified_ts = ? ' .
			     'WHERE topicid = ? AND fileline = ? ' .
			     'AND filenumber = ? AND filenew = ?');

    my $success = defined $select_comments && defined $update_comments;
    my $rc = $Codestriker::OK;

    # Retrieve the current comment data.
    $success &&= $select_comments->execute($self->{topicid}, 
     				           $self->{fileline},
                                           $self->{filenumber},
					   $self->{filenew});

    # Make sure that the topic still exists, and is therefore valid.
    my ($current_version, $current_stateid, $creation_ts);
    if ($success && 
	! (($current_version, $current_stateid, $creation_ts)
	   = $select_comments->fetchrow_array())) {
	# Invalid topic id.
	$success = 0;
	$rc = $Codestriker::INVALID_TOPIC;
    }
    $success &&= $select_comments->finish();

    # Check the version number.
    if ($success && $version != $self->{version}) {
	$success = 0;
	$rc = $Codestriker::STALE_VERSION;
    }

    # If the state hasn't changed, don't do anything, otherwise update the
    # comments.
    if ($new_stateid != $self->{state}) {
    	$self->{version} = $self->{version} + 1;
        $self->{state} = $new_stateid;
	$self->{modified_ts} = $timestamp;
	$success &&= $update_comments->execute($self->{version},
 					       $self->{state},
					       $self->{creation_ts},
					       $timestamp,
					       $self->{topicid}, 
                                               $self->{fileline},
					       $self->{filenumber}, 
                                               $self->{filenew});
    }
    
    Codestriker::DB::DBI->release_connection($dbh, $success);
    
    return $rc;
}

# Class method to convert state name to state id, returns -1 if the
# state name is invalid.
sub convert_state_to_stateid {
    my ($comment_state) = @_;
    
    # Map the state name to its number.
    my $stateid = -1;
    my $id;
    for ($id = 0; $id <= $#Codestriker::comment_states; $id++) {
	last if ($Codestriker::comment_states[$id] eq $comment_state);
    }
    if ($id <= $#Codestriker::comment_states) {
	$stateid = $id;
    }
}    


1;
