###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling topic file data.

package Codestriker::Model::Delta;

use strict;
use Encode qw(decode_utf8);

# Create the appropriate delta rows for this review. This gets called
# by File::get_deltas. It passes in the result of a sql query on the
# delta table.
sub new {
    my $class = shift;
    my $self = {};
    bless $self;

    $self->{filename} = decode_utf8($_[1]);
    $self->{revision} = $_[2];
    $self->{binary} = $_[3];
    $self->{old_linenumber} = $_[4];
    $self->{new_linenumber} = $_[5];
    $self->{text} = decode_utf8($_[6]);
    $self->{description} = (defined $_[7]) ? decode_utf8($_[7]) : "";
    $self->{filenumber} = $_[8];
    $self->{repmatch} = $_[9];
    $self->{only_delta_in_file} = 0;

    return $self;
}

# Retrieve the number of lines in the data for a given file.
# Input -1 for filenumber for a full file list of a specific topic.
sub get_delta_size($$$) {
    my ($type, $topicid, $filenumber) = @_;

    my @deltas = ();
    @deltas = $type->get_deltas($topicid, $filenumber);

    my $addedLines = 0;
    my $removedLines = 0;

    for (my $i = 0; $i <= $#deltas; $i++) {
        my $delta = $deltas[$i];
        my @lines = split '\n', $delta->{text};

        for (my $j = 0; $j <= $#lines; $j++) {
            my @aLine = $lines[$j];
            if (scalar( grep !/^\+/, @aLine ) == 0) {
                $addedLines++;
            } elsif (scalar( grep !/^\-/, @aLine ) == 0) {
                $removedLines++;
            }
        }
    }

    my $numLines = "";

    # Return the changes if one is non zero.
    if (($removedLines != 0) || ($addedLines != 0)) {
        $numLines = "+$addedLines,-$removedLines";
    }

    return $numLines;
}


# Retrieve the ordered list of deltas that comprise this review.
# Input -1 for filenumber for a full file list of a specific topic.
sub get_delta_set($$$) {
    my ($type, $topicid, $filenumber) = @_;
    return $type->get_deltas($topicid, $filenumber);
}

# Retrieve the delta for the specific filename and linenumber.
sub get_delta($$$) {
    my ($type, $topicid, $filenumber, $linenumber, $new) = @_;

    # Grab all the deltas for this file, and grab the delta with the highest
    # starting line number lower than or equal to the specific linenumber,
    # and matching the same file number.
    my @deltas = $type->get_deltas($topicid, $filenumber);
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

# Retrieve the ordered list of deltas applied to a specific file. Class factory
# method, returns a list of delta objects.
sub get_deltas($$$) {
    my ($type, $topicid, $filenumber) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Setup the appropriate statement and execute it.
    my $select_deltas =
      $dbh->prepare_cached('SELECT delta_sequence, filename, revision, ' .
                           'binaryfile, old_linenumber, new_linenumber, ' .
                           'deltatext, description, topicfile.sequence, ' .
                           'repmatch FROM topicfile, delta ' .
                           'WHERE delta.topicid = ? AND ' .
                           'delta.topicid = topicfile.topicid AND ' .
                           'delta.file_sequence = topicfile.sequence ' .
                           (($filenumber != -1) ?
                            'AND topicfile.sequence = ? ' : '') .
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
            my $delta = Codestriker::Model::Delta->new( @data );
            push @results, $delta;
        }
    }

    # The delta object needs to know if there are only delta objects
    # in this file so it can figure out if the delta is a new file.

    # Set the 'only_delta_in_file' field for each delta.
    if (scalar(@results) > 0) {
        # Assume the first delta is the only delta unless proven otherwise.
        $results[0]->{only_delta_in_file} = 1;
        for (my $i = 1; $i < scalar(@results); $i++) {
            if ($results[$i-1]->{filenumber} == $results[$i]->{filenumber}) {
                # If the previous file has the same filenumber, then
                # we know that neither the current file nor the
                # previous file are the only deltas for the file.
                $results[$i]->{only_delta_in_file} = 0;
                $results[$i-1]->{only_delta_in_file} = 0;
            } else {
                # This is the first delta of a file.  We'll assume it's the
                # only delta for this file.  If there are more deltas, the next
                # loop will correct the assumption.
                $results[$i]->{only_delta_in_file} = 1;
            }
        }
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;

    return @results;
}

# Determine the offset of $target_line within the delta text. or -1
# if it can't be located.
sub find_line_offset {
    my ($self, $targetline, $new) = @_;

    # Break the text into lines.
    my @document = split /\n/, $self->{text};

    # Calculate the location of the target line within the diff chunk.
    my $offset;
    my $old_linenumber = $self->{old_linenumber};
    my $new_linenumber = $self->{new_linenumber};
    for ($offset = 0; $offset <= $#document; $offset++) {

        my $data = $document[$offset];

        # Check if the target line as been found.
        if ($data =~ /^ /o) {
            last if ($new && $new_linenumber == $targetline);
            last if ($new == 0 && $old_linenumber == $targetline);
            $old_linenumber++;
            $new_linenumber++;
        } elsif ($data =~ /^\+/o) {
            last if ($new && $new_linenumber == $targetline);
            $new_linenumber++;
        } elsif ($data =~ /^\-/o) {
            last if ($new == 0 && $old_linenumber == $targetline);
            $old_linenumber++;
        }
    }

    if (($new && $new_linenumber == $targetline) ||
        ($new == 0 && $old_linenumber == $targetline)) {
        return $offset;
    } else {
        # No match was found.
        return -1;
    }
}

# Retrieve the textual context for the delta at the specified line and
# context width.
sub retrieve_context {
    my ($self, $targetline, $new, $context, $text) = @_;

    my $offset = $self->find_line_offset($targetline, $new);
    if ($offset == -1) {
        return -1;
    }

    # Get the minimum and maximum line numbers for this context, and return
    # the data.
    my @document = split /\n/, $self->{text};
    my $min_line = ($offset - $context < 0 ? 0 : $offset - $context);
    my $max_line = $offset + $context;
    for (my $i = $min_line; $i <= $max_line && $i <= $#document; $i++) {
        push @{ $text }, $document[$i];
    }

    return $offset - $min_line;
}

1;
