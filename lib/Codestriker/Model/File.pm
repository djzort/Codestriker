###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling topic file data.

package Codestriker::Model::File;

use strict;

# Create the appropriate delta rows for this review.  Note this gets called
# from Topic::create(), which controls the transaction commit/rollback.
sub create($$$$$) {
    my ($type, $dbh, $topicid, $deltas_ref, $repository_root) = @_;

    # Create the appropriate prepared statements.
    my $insert_file =
	$dbh->prepare_cached('INSERT INTO file (topicid, sequence, filename,' .
			     ' topicoffset, revision, diff, binaryfile) ' .
			     'VALUES (?, ?, ?, ?, ?, ?, ?)');
    my $success = defined $insert_file;

    my $insert_delta =
	$dbh->prepare_cached('INSERT INTO delta (topicid, file_sequence, ' .
			     'delta_sequence, old_linenumber, ' .
			     'new_linenumber, deltatext, ' .
			     'description, repmatch) ' .
			     'VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
    $success &&= defined $insert_delta;

    my @deltas = @$deltas_ref;
    my $last_filename = "";
    my $file_sequence = -1;
    my $delta_sequence = -1;
    for (my $i = 0; $i <= $#deltas; $i++) {
	my $delta = $deltas[$i];
	if ($last_filename ne $delta->{filename}) {
	    # Create new file entry.
	    $success &&= $insert_file->execute($topicid, ++$file_sequence,
					       $delta->{filename}, -1,
					       $delta->{revision}, "",
					       $delta->{binary});
	    $last_filename = $delta->{filename};
	}

	# Add the new delta entry.
	$success &&= $insert_delta->execute($topicid, $file_sequence,
					    ++$delta_sequence,
					    $delta->{old_linenumber},
					    $delta->{new_linenumber},
					    $delta->{text},
					    $delta->{description},
					    $delta->{repmatch});
    }

    die $dbh->errstr unless $success;
}

# Retrieve the details of a file for a specific topicid and filenumber.
sub get($$$$$$) {
    my ($type, $topicid, $filenumber,
	$offset_ref, $revision_ref, $diff_ref) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Retrieve the file information.
    my $select_file =
	$dbh->prepare_cached('SELECT topicoffset, revision, diff FROM file' .
			     ' WHERE topicid = ? AND sequence = ?');
    my $success = defined $select_file;
    $success &&= $select_file->execute($topicid, $filenumber);
    
    if ($success) {
	my ($offset, $revision, $diff) = $select_file->fetchrow_array();
	
	# Store the results in the reference variables and return.
	$$offset_ref = $offset;
	$$revision_ref = $revision;
	$$diff_ref = $diff;
	$select_file->finish();
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;
}

# Retrieve the details of which files, revisions and offsets are present for
# a specific topic.
sub get_filetable($$$$$$) {
    my ($type, $topicid, $filename_array_ref, $revision_array_ref,
	$offset_array_ref, $binary_array_ref) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Setup the appropriate statement and execute it.
    my $select_file =
	$dbh->prepare_cached('SELECT filename, revision, topicoffset, ' .
			     'binaryfile FROM file WHERE topicid = ? ' .
			     'ORDER BY sequence');
    my $success = defined $select_file;
    $success &&= $select_file->execute($topicid);
    
    # Store the results in the referenced arrays.
    if ($success) {
	my @data;
	while (@data = $select_file->fetchrow_array()) {
	    push @$filename_array_ref, $data[0];
	    push @$revision_array_ref, $data[1];
	    push @$offset_array_ref, $data[2];
	    push @$binary_array_ref, $data[3];
	}
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;
}

# Retrieve the ordered list of deltas that comprise this review.
sub get_delta_set($$) {
    my ($type, $topicid) = @_;
    return $type->get_deltas($topicid, -1);
}

# Retrieve the ordered list of deltas applied to a specific file.
sub get_deltas($$$) {
    my ($type, $topicid, $filenumber) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Setup the appropriate statement and execute it.
    my $select_deltas =
	$dbh->prepare_cached('SELECT delta_sequence, filename, revision, ' .
			     'binaryfile, old_linenumber, new_linenumber, ' .
			     'deltatext, description, file.sequence, ' .
			     'repmatch FROM file, delta ' .
			     'WHERE delta.topicid = ? AND ' .
			     'delta.topicid = file.topicid AND ' .
			     'delta.file_sequence = file.sequence ' .
			     (($filenumber != -1) ?
			      'AND file.sequence = ? ' : '').
			     'ORDER BY delta_sequence ASC');

    my $success = defined $select_deltas;
    if ($filenumber != -1) {
	$success &&= $select_deltas->execute($topicid, $filenumber);
    } else {
	$success &&= $select_deltas->execute($topicid);
    }
    
    # Store the results into an array of objects.
    my @results = ();
    if ($success) {
	my @data;
	while (@data = $select_deltas->fetchrow_array()) {
	    my $delta = {};
	    $delta->{filename} = $data[1];
	    $delta->{revision} = $data[2];
	    $delta->{binary} = $data[3];
	    $delta->{old_linenumber} = $data[4];
	    $delta->{new_linenumber} = $data[5];
	    $delta->{text} = $data[6];
	    $delta->{description} = $data[7];
	    $delta->{filenumber} = $data[8];
	    $delta->{repmatch} = $data[9];
	    push @results, $delta;
	}
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;

    return @results;
}

# Retrieve the delta for the specific filename and linenumber.
sub get_delta($$$) {
    my ($type, $topicid, $filenumber, $linenumber, $new) = @_;

    # Grab all the deltas for this file, and grab the delta with the highest
    # starting line number lower than or equal to the specific linenumber,
    # and matching the same file number.
    my @deltas = Codestriker::Model::File->get_deltas($topicid, $filenumber);
    my $found_delta = undef;
    for (my $i = 0; $i <= $#deltas; $i++) {
	my $delta = $deltas[$i];
	my $delta_linenumber = $new ?
	    $delta->{new_linenumber} : $delta->{old_linenumber};
	if ($delta_linenumber <= $linenumber) {
	    $found_delta = $delta;
	} else {
	    # Passed the delta of interest, return the previous one found.
	    return $found_delta;
	}
    }
	
    # Return the matching delta found, if any.
    return $found_delta;
}

1;
