###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling topic file data.

package Codestriker::Model::File;

use strict;

# Go through the document text, and if it is a diff file (CVS or patch),
# create a new row for each file in the file table.  Note this gets called
# from Topic::create(), which controls the transaction commit/rollback.
sub create($$$$$) {
    my ($type, $dbh, $topicid, $document_text, $repository_root) = @_;

    # Break the document into lines, and remove any \r characters.
    my @document = split /\n/, $document_text;
    return if ($#document == -1);  # Nothing to do.
    for (my $i = 0; $i <= $#document; $i++) {
	$document[$i] =~ s/\r//g;
    }

    # Create the appropriate prepared statements.
    my $insert_file =
	$dbh->prepare_cached('INSERT INTO file (topicid, sequence, filename,' .
			     ' topicoffset, revision, diff, binaryfile) ' .
			     'VALUES (?, ?, ?, ?, ?, ?, ?)');
    my $success = defined $insert_file;

    my $offset = 0;
    my $filename = "";
    my $revision = "";
    my $binary = 0;
    for (my $sequence_number = 0;
	 $success && _read_diff_header(\@document, \$offset, \$filename,
				       \$revision, \$binary, $repository_root);
	 $sequence_number++) {

	# Record the offset marking the start of program code.
	my $diff_offset = $offset;

	# Now collect the data which corresponds to this diff hunk, and
	# create a row for it.
	my $diff;
	for ($diff = ""; $offset <= $#document; $offset++) {
	    # If the start of next diff header has been reached, the diff hunk
	    # has been read.
	    my $line = $document[$offset];
	    last if ($line =~ /^Index/o || $line =~ /^diff/o ||
		     $line =~ /^Binary/o || $line =~ /^Only/o);
	    $diff .= $line . "\n";
	}

	# Create the appropriate file row.
	$success &&= $insert_file->execute($topicid, $sequence_number,
					   $filename, $diff_offset, $revision,
					   $diff, $binary);
    }

    die $dbh->errstr unless $success;
}

# Retrieve the details of a file for a specific topicid and filename.
sub get($$$$$$) {
    my ($type, $topicid, $filename,
	$offset_ref, $revision_ref, $diff_ref) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Retrieve the file information.
    my $select_file =
	$dbh->prepare_cached('SELECT topicoffset, revision, diff FROM file' .
			     ' WHERE topicid = ? AND filename = ?');
    my $success = defined $select_file;
    $success &&= $select_file->execute($topicid, $filename);
    
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
