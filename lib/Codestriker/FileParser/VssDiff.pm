###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Parser object for reading VSS (Visual Source Safe) diffs.

package Codestriker::FileParser::VssDiff;

use strict;
use Codestriker::FileParser::BasicDiffUtils;

# Return the array of filenames, revision number, linenumber, whether its
# binary or not, and the diff text.
# Return () if the file can't be parsed, meaning it is in another format.
sub parse ($$$) {
    my ($type, $fh, $repository) = @_;

    # Array of results found.
    my @result = ();

    my $line = <$fh>;
    while (defined($line)) {
	# Values associated with the diff.
	my $revision;
	my $filename;

	# Skip whitespace.
	while (defined($line) && $line =~ /^\s*$/o) {
	    $line = <$fh>;
	}
	return @result unless defined $line;

	# For VSS diffs, the start of the diff block is the "Diffing:" line
	# which contains the filename and version number.
	return () unless defined $line && $line =~ /^Diffing: (.*);(.+)$/o;
	$filename = $1;
	$revision = $2;

	# The next line will be the "Against:" line, followed by a blank line.
	$line = <$fh>;
	return () unless defined $line && $line =~ /^Against:/o;
	$line = <$fh>;
	return () unless defined $line && $line =~ /^\s*$/o;

	# The next part of the diff will be the old style diff format, or
	# possibly "No differences." if there are no differences.
	$line = <$fh>;
	if ($line !~ /^No differences\./) {
	    my $chunk;
	    do
	    {
		$chunk = Codestriker::FileParser::BasicDiffUtils->read_diff_text(
		       $fh, $line, $filename, $revision, 1);
		if (defined $chunk) {
		    push @result, $chunk;
		    $line = <$fh>;
		}
	    } while (defined $chunk);
	}

	# Read the next line.
	$line = <$fh>;
    }

    # Return the found diff chunks.
    return @result;
}
	
1;
