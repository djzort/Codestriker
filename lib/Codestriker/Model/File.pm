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
			     'new_linenumber, deltatext, description) ' .
			     'VALUES (?, ?, ?, ?, ?, ?, ?)');
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
					    $delta->{description});
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
			     'deltatext, description, file.sequence ' .
			     'FROM file, delta ' .
			     'WHERE delta.topicid = ? AND ' .
			     'delta.topicid = file.topicid AND ' .
			     'delta.file_sequence = file.sequence ' .
			     (($filenumber != -1) ? 'file.sequence = ? ' : '').
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

# DEPRECATED - used only for data migration purposes.
# Read from $fh, and return true if we have read a diff header, with all of
# the appropriate values set to the reference variables passed in.
sub _read_diff_header($$$$$$$) {
    my ($doc_array_ref, $offset, $filename, $revision, $binary,
	$repository_root) = @_;

    # Files are text by default.
    $$binary = 0;

    # Note we only iterate while handling empty diff blocks.
    my @document = @$doc_array_ref;
    my $size = $#document;

    while ($$offset <= $size) {
	my $line = $$doc_array_ref[$$offset++];

	# Read any ? lines, denoting unknown files to CVS.
	# Also remove any blank lines.
	while ($line =~ /^\?/o || $line =~ /^\s*$/) {
	    $line = $$doc_array_ref[$$offset++];
	}
	return 0 unless defined $line;
	
	# For CVS diffs, the Index line is next.
	if ($line =~ /^Index:/o) {
	    $line = $$doc_array_ref[$$offset++];
	    return 0 unless defined $line;
	}
	
	# Then we expect the separator line, for CVS diffs.
	if ($line =~ /^===================================================================$/) {
	    $line = $$doc_array_ref[$$offset++];
	    return 0 unless defined $line;
	}
	
	# Now we expect the RCS line, whose filename should include the CVS
	# repository, and if not, it is probably a new file.  if there is no
	# such line, we could still be dealing with an ordinary patch file.
	my $cvs_diff = 0;
	if ($line =~ /^RCS file: $repository_root\/(.*),v$/) {
	    $$filename = $1;
	    $line = $$doc_array_ref[$$offset++];
	    return 0 unless defined $line;
	    $cvs_diff = 1;
	} elsif ($line =~ /^RCS file: (.*)$/o) {
	    $$filename = $1;
	    $line = $$doc_array_ref[$$offset++];
	    return 0 unless defined $line;
	    $cvs_diff = 1;
	}
	
	# Now we expect the retrieving revision line, unless it is a new or
	# removed file.
	if ($line =~ /^retrieving revision (.*)$/o) {
	    $$revision = $1;
	    $line = $$doc_array_ref[$$offset++];
	    return 0 unless defined $line;
	}

	# If we are doing a diff between two revisions, a second revision
	# line will appear.  Don't care what the value of the second
	# revision is.
	if ($line =~ /^retrieving revision (.*)$/o) {
	    $line = $$doc_array_ref[$$offset++];
	}
	
	# Need to check for binary file differences for patch files.
	# Unfortunately, when you provide the "-N" argument to diff, then
	# it doesn't indicate new files or removed files properly.  Without
	# the -N argument, it then indicates "Only in ...".
	if ($line =~ /^Binary files (.*) and .* differ$/) {
	    $$filename = $1;
	    $$revision = $Codestriker::PATCH_REVISION;
	    $$binary = 1;
	    return 1;
	} elsif ($line =~ /^Only in (.*): (.*)$/) {
	    $$filename = "$1/$2";
	    $$revision = $Codestriker::PATCH_REVISION;
	    $$binary = 1;
	    return 1;
	}    

	# Now read in the diff line, followed by the legend lines.  If this is
	# not present, then we know we aren't dealing with a diff file of any
	# kind.
	return 0 unless $line =~ /^diff/o;
	$line = $$doc_array_ref[$$offset++];
	return 0 unless defined $line;

	# If the diff is empty (since we may have used the -b flag), continue
	# processing the next diff header back around this loop.  Note this is
	# only an issue with cvs diffs.  Ordinary diffs just don't include
	# a diff section if it is blank.
	next if ($line =~ /^Index:/o);

	# Check for binary files being added, changed or removed.
	if ($line =~ /^Binary files \/dev\/null and (.*) differ$/o) {
	    # Binary file has been added.
	    $$revision = $Codestriker::ADDED_REVISION;
	    $$binary = 1;
	    return 1;
	} elsif ($line =~ /^Binary files .* and \/dev\/null differ$/o) {
	    # Binary file has been removed.
	    $$revision = $Codestriker::REMOVED_REVISION;
	    $$binary = 1;
	    return 1;
	} elsif ($line =~ /^Binary files .* and .* differ$/o) {
	    # Binary file has been modified.
	    $$revision = $$revision;
	    $$binary = 1;
	    return 1;
	} elsif ($line =~ /^\-\-\- \/dev\/null/o) {
	    # File has been added.
	    $$revision = $Codestriker::ADDED_REVISION;
	} elsif ($cvs_diff == 0 &&
		 $line =~ /^\-\-\- (.+?)\t.*$/o) {
	    $$filename = $1;
	    $$revision = $Codestriker::PATCH_REVISION;
	} elsif (! $line =~ /^\-\-\-/o) {
	    return 0;
	}
	
	$line = $$doc_array_ref[$$offset++];
	return 0 unless defined $line;
	if ($line =~ /^\+\+\+ \/dev\/null/o) {
	    # File has been removed.
	    $$revision = $Codestriker::REMOVED_REVISION;
	} elsif (! $line =~ /^\+\+\+/o) {
	    return 0;
	}
	
	# Now up to the line chunks, so the diff header has been successfully
	# read.
	return 1;
    }
}

1;
