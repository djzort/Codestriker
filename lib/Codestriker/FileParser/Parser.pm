###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Main delegate parser object, which tries a bunch of parsers to determine what
# format the input review is in.  The last resort, is to view it as 
# unstructured text, if it is content-type plain/text, otherwise indicate
# an error.

package Codestriker::FileParser::Parser;

use strict;

use Codestriker::FileParser::CvsUnidiff;
use Codestriker::FileParser::PatchUnidiff;
use Codestriker::FileParser::UnknownFormat;

# Given the content-type and the file handle, try to determine what files,
# lines, revisions and diffs have been submitted in this review.
sub parse ($$$$) {
    my ($type, $fh, $content_type, $repository) = @_;

    # Diffs found.
    my @diffs = ();

    # If the file is plain/text, try all of the text parsers.
    if ($content_type eq "text/plain") {

	# Check if it is a CVS unidiff file.
	if ($#diffs == -1) {
	    seek($fh, 0, 0);
	    @diffs =
		Codestriker::FileParser::CvsUnidiff->parse($fh,
							   $repository);
	}
	
	# Check if it is a patch unidiff file.
	if ($#diffs == -1) {
	    seek($fh, 0, 0);
	    @diffs =
		Codestriker::FileParser::PatchUnidiff->parse($fh,
							     $repository);
	}

	# Last stop-gap - the file format is unknown, treat it as a
	# single file with filename "unknown".
	if ($#diffs == -1) {
	    seek($fh, 0, 0);
	    @diffs = Codestriker::FileParser::UnknownFormat->parse($fh);
	}
    } elsif ($content_type eq "application/gzip" ||
	     $content_type eq "application/x-gzip") {
	# Check if it is a gzip file.

    } elsif ($content_type eq "application/zip" ||
	     $content_type eq "application/x-zip") {
	# Check if it is a zip file.
    }

    # Restore the offset back to the start of the file again.
    seek($fh, 0, 0);

    # Return the diffs found, if any.
    return @diffs;
}

1;

