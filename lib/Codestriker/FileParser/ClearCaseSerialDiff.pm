###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Parser object for reading ClearCase serial diff formats.

package Codestriker::FileParser::ClearCaseSerialDiff;

use strict;
use Codestriker::FileParser::BasicDiffUtils;

# Return the array of filenames, revision number, linenumber and the diff text.
# Return () if the file can't be parsed, meaning it is in another format.
sub parse ($$) {
    my ($type, $fh) = @_;

    # Array of results found.
    my @result = ();

    # The current filename and revision being tracked.
    my $revision = $Codestriker::PATCH_REVISION;
    my $filename = "";

    # Ignore any whitespace at the start of the file.
    my $line = <$fh>;
    while (defined($line)) {
	# Skip any heading or trailing whitespace contained in the review
	# text.
	while (defined($line) && $line =~ /^\s*$/o) {
	    $line = <$fh>;
	}
	return @result unless defined $line;

	# Check if the next fileheader is being read.
	if (defined $line &&
	    $line =~ /^\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*$/o) {

	    # Now read the file that has been modified.
	    $line = <$fh>;
	    return () unless
		defined $line && $line =~ /^\<\<\< file 1\: (.*)\@\@(.*)$/o;
	    $filename = $1;
	    $revision = $2;

	    # Read the next line which is the local file.
	    $line = <$fh>;
	    return () unless
		defined $line && $line =~ /^\>\>\> file 2\: .*$/o;
	    
	    # Now expect the end of the file header.
	    $line = <$fh>;
	    return () unless
		defined $line && $line =~ /^\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*$/o;

	    # Read the next line.
	    $line = <$fh>;
	    return () unless defined $line;
	}

	# Read the next diff chunk.
	my $chunk =
	    Codestriker::FileParser::BasicDiffUtils->read_diff_text(
		       $fh, $line, $filename, $revision, 0);
	return () unless defined $chunk;
	push @result, $chunk;

	# Read the next line.
	$line = <$fh>;
    }

    # Return the found diff chunks.
    return @result;
}

1;

    
