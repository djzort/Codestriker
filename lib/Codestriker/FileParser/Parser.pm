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

use FileHandle;
use Codestriker::FileParser::CvsUnidiff;
use Codestriker::FileParser::SubversionDiff;
use Codestriker::FileParser::VssDiff;
use Codestriker::FileParser::PatchUnidiff;
use Codestriker::FileParser::UnknownFormat;

# Given the content-type and the file handle, try to determine what files,
# lines, revisions and diffs have been submitted in this review.
sub parse ($$$$$) {
    my ($type, $fh, $content_type, $repository, $topicid,
	$uploaded_filename) = @_;

    # Diffs found.
    my @diffs = ();

    # This is a pain, but to handle diffs produced on a windoze box, which
    # uses \r\n endings, rather than making each parser object take this
    # into account, create a temporary file here which removes them, and
    # that file handle is passed on to the parser objects, so they aren't
    # the wiser.
    my $tmp_filename = "tmpparse.$topicid";
    open(TMP, ">$tmp_filename") ||
	die "Unable to create temporary parse file: $!";
    while (<$fh>) {
	my $line = $_;
	$line =~ s/\r\n/\n/go;
	print TMP $line;
    }
    close TMP;
    my $tmpfh = new FileHandle "$tmp_filename", "r";
    die "Unable to open temporary parse file: $!" if (! defined $tmpfh);

    # If the file is plain/text, try all of the text parsers.
    if ($content_type eq "text/plain") {

	# Check if it is a CVS unidiff file.
	if ($#diffs == -1) {
	    seek($tmpfh, 0, 0);
	    @diffs =
		Codestriker::FileParser::CvsUnidiff->parse($tmpfh,
							   $repository);
	}

	# Check if it is a Subversion diff file.
	if ($#diffs == -1) {
	    seek($tmpfh, 0, 0);
	    @diffs =
		Codestriker::FileParser::SubversionDiff->parse($tmpfh,
							       $repository);
	}

	# Check if it is a VSS diff file.
	if ($#diffs == -1) {
	    seek($tmpfh, 0, 0);
	    @diffs =
		Codestriker::FileParser::VssDiff->parse($tmpfh,
							$repository);
	}

	# Check if it is a patch unidiff file.
	if ($#diffs == -1) {
	    seek($tmpfh, 0, 0);
	    @diffs =
		Codestriker::FileParser::PatchUnidiff->parse($tmpfh,
							     $repository);
	}

	# Last stop-gap - the file format is unknown, treat it as a
	# single file with filename "unknown".
	if ($#diffs == -1) {
	    seek($tmpfh, 0, 0);
	    @diffs = Codestriker::FileParser::UnknownFormat->
		parse($tmpfh, $uploaded_filename);
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

    # Remove the temporary file.
    unlink $tmp_filename;

    # Return the diffs found, if any.
    return @diffs;
}

1;

