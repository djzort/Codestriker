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

# Create a new topic with all of the specified properties.
sub create($$$$$) {
    my ($type, $topicid, $line, $email, $data) = @_;
    
    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Create the prepared statements.
    my $insert_comment =
	$dbh->prepare_cached('INSERT INTO COMMENT (topicid, commentfield, ' .
			     'author, line, creation_ts) ' .
			     'VALUES (?, ?, ?, ?, ?)')
	|| die "Failed to create prepared statement: " . $dbh->errstr;

    # Create the comment row.
    my $timestamp = Codestriker->get_current_timestamp();
    $insert_comment->execute($topicid, $data, $email, $line, $timestamp) ||
	die "Failed to insert comment: " . $dbh->errstr;

    $dbh->commit;
}

# Read all of the comments made for a specified topic, and store the results
# in the passed-in array references.
sub read($$\@\@\@\@\%) {
    my ($type, $topicid, $linearray_ref, $dataarray_ref, $authorarray_ref,
	$datearray_ref, $existshash_ref) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Retrieve all of the comment information for the specified topicid.
    my $select_comment =
	$dbh->prepare_cached('SELECT commentfield, author, line, ' .
			     'creation_ts FROM comment WHERE topicid = ?')
	|| die "Creation of prepared statement failed: " . $dbh->errstr;
    $select_comment->execute($topicid)
	|| die "Couldn't execute statement: " . $dbh->errstr;

    # Store the results into the referenced arrays.
    my @data;
    while (@data = $select_comment->fetchrow_array()) {
	push @$dataarray_ref, $data[0];
	push @$authorarray_ref, $data[1];
	push @$linearray_ref, $data[2];
	push @$datearray_ref, Codestriker->format_timestamp($data[3]);
	$$existshash_ref{$data[2]} = 1;
    }
}

1;
