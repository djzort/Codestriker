###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Parser object for reading CVS diffs.

package Codestriker::FileParser::CvsUnidiff;

use strict;

# Return the array of filenames, revision number, linenumber, whether its
# binary or not, and the diff text.
# Return undef if the file can't be parsed, meaning it is in another format.
sub parse ($$$) {
    my ($type, $fh, $repository) = @_;

    my $repository_root =
	(defined $repository) ? $repository->getRoot() : undef;

    # Array of results found.
    my @result = ();

    # CVS diffs may start with a number of unknown files, which start with a
    # ? character.  These lines can be skipped, as can blank lines.
    my $line = <$fh>;
    while (defined($line) && ($line =~ /^\?/o || $line =~ /^\s*$/)) {
        $line = <$fh>;
    }
    return () unless defined $line;

    while (defined($line)) {
	# Values associated with the diff.
	my $revision;
	my $filename = "";
	my $old_linenumber = -1;
	my $new_linenumber = -1;
	my $binary = 0;
	my $diff;

	# For CVS diffs, the start of the diff block is the Index line.
	return () unless defined $line && $line =~ /^Index:/o;
	$line = <$fh>;

	# The separator line appears next.
	return () unless defined $line && $line =~ /^===================================================================$/;
	$line = <$fh>;

	# Now we expect the RCS line, whose filename should include the CVS
	# repository, and if not, it is probably a new file.
	return () unless defined $line;
	if (defined $repository_root &&
	    $line =~ /^RCS file: $repository_root\/(.*),v$/) {
	    $filename = $1;
	    $line = <$fh>;
	    return () unless defined $line;
	} elsif ($line =~ /^RCS file: (.*)$/o) {
	    $filename = $1;
	    $line = <$fh>;
	    return () unless defined $line;
	}
	
	# Now we expect the retrieving revision line, unless it is a new or
	# removed file.
	if ($line =~ /^retrieving revision (.*)$/o) {
	    $revision = $1;
	    $line = <$fh>;
	    return () unless defined $line;
	}

	# If we are doing a diff between two revisions, a second revision
	# line will appear.  Don't care what the value of the second
	# revision is.
	if ($line =~ /^retrieving revision (.*)$/o) {
	    $line = <$fh>;
	}
	
	# Now read in the diff line, followed by the legend lines.  If this is
	# not present, then we know we aren't dealing with a diff file of any
	# kind.
	return () unless $line =~ /^diff/o;
	$line = <$fh>;
	return () unless defined $line;

	# If the diff is empty (since we may have used the -b flag), continue
	# processing the next diff header back around this loop.  Note this is
	# only an issue with cvs diffs.  Ordinary diffs just don't include
	# a diff section if it is blank.
	next if ($line =~ /^Index:/o);

	# Check for binary files being added, changed or removed.
	if ($line =~ /^Binary files \/dev\/null and (.*) differ$/o) {
	    # Binary file has been added.
	    $revision = $Codestriker::ADDED_REVISION;
	    $binary = 1;
	} elsif ($line =~ /^Binary files .* and \/dev\/null differ$/o ||
		 $line =~ /^Binary files .* and .* differ$/o) {
	    # Binary file has been removed.
	    $revision = $Codestriker::REMOVED_REVISION;
	    $binary = 1;
	} elsif ($line =~ /^\-\-\- \/dev\/null/o) {
	    # File has been added.
	    $revision = $Codestriker::ADDED_REVISION;
	} elsif (! $line =~ /^\-\-\-/o) {
	    return ();
	}

	# Now expect the +++ line.
	$line = <$fh>;
	return () unless (defined $line && $line =~ /^\+\+\+/o);
	
	# Check if it is a removed file.
	if ($line =~ /^\+\+\+ \/dev\/null/o) {
	    # File has been removed.
	    $revision = $Codestriker::REMOVED_REVISION;
	}

	# Now read in the multiple chunks.
	$line = <$fh>;
	while (defined $line &&
	       $line =~ /^\@\@ \-(\d+)\,\d+ \+(\d+)\,\d+ \@\@/) {
	    $old_linenumber = $1;
	    $new_linenumber = $2;


	    # Now read in the diff text until finished.
	    $line = <$fh>;
	    $diff = "";
	    while (defined $line && $line =~ /^[ \-\+]/o) {
		$diff .= $line;
		$line = <$fh>;
	    }

	    my $chunk = {};
	    $chunk->{filename} = $filename;
	    $chunk->{revision} = $revision;
	    $chunk->{old_linenumber} = $old_linenumber;
	    $chunk->{new_linenumber} = $new_linenumber;
	    $chunk->{binary} = $binary;
	    $chunk->{text} = $diff;
	    $chunk->{description} = "";
	    push @result, $chunk;

	    print STDERR "Got filename $filename rev $revision\n";
	}
    }

    # Return the found diff chunks.
    return @result;
}
	
1;

    
