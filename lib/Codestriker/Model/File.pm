###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling topic file data.

package Codestriker::Model::File;

use strict;
use Codestriker::Model::Delta;

# Create the appropriate delta rows for this review.  Note this gets called
# from Topic::create(), which controls the transaction commit/rollback.
sub create($$$$) {
    my ($type, $dbh, $topicid, $deltas_ref) = @_;

    # Create the appropriate prepared statements.
    my $insert_file =
      $dbh->prepare_cached('INSERT INTO topicfile ' .
                           '(topicid, sequence, filename,' .
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
            $success &&= $insert_file->execute($topicid,
                                               ++$file_sequence,
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
      $dbh->prepare_cached('SELECT topicoffset, revision, diff ' .
                           'FROM topicfile ' .
                           'WHERE topicid = ? AND sequence = ?');
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
sub get_filetable($$$$$$$) {
    my ($type, $topicid, $filename_array_ref, $revision_array_ref,
        $offset_array_ref, $binary_array_ref, $numchanges_array_ref) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Setup the appropriate statement and execute it.
    my $select_file =
      $dbh->prepare_cached('SELECT filename, revision, topicoffset, ' .
                           'binaryfile, sequence FROM topicfile ' .
                           'WHERE topicid = ? ' .
                           'ORDER BY sequence');
    my $success = defined $select_file;
    $success &&= $select_file->execute($topicid);

    # Store the results in the referenced arrays.
    if ($success) {
        my @data;
        my @sequence;
        while (@data = $select_file->fetchrow_array()) {
            push @$filename_array_ref, $data[0];
            push @$revision_array_ref, $data[1];
            push @$offset_array_ref, $data[2];
            push @$binary_array_ref, $data[3];
            push @sequence, $data[4];
        }
        $select_file->finish();

        # This has to be called outside the loop above, as SQL Server
        # doesn't allow nested selects... gggrrrr.
        foreach my $file_id (@sequence) {
            # Now get the number of lines affected in this file
            my $numchanges = Codestriker::Model::Delta->get_delta_size($topicid, $file_id);

            push @$numchanges_array_ref, $numchanges;
        }
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;
}


1;
