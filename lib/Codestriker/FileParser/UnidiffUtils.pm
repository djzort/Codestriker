###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Utility object for reading unidiffs.

package Codestriker::FileParser::UnidiffUtils;

use strict;

# Read from the file the diff chunks, and return them.
sub read_unidiff_text($$$$) {
    my ($type, $fh, $filename, $revision, $repmatch) = @_;

    # List of diff chunks read.
    my @result = ();

    my $lastpos = tell $fh;
    my $line = <$fh>;
    while (defined $line &&
	   $line =~ /^\@\@ \-(\d+)(\,\d+)? \+(\d+)(\,\d+)? \@\@/) {
	my $old_linenumber = $1;
	my $new_linenumber = $3;

	# Now read in the diff text until finished.
	my $diff = "";
	$line = <$fh>;
	while (defined $line && $line =~ /^[ \-\+\\]/o) {
	    # Skip lines line "\ No newline at end of file".
	    $diff .= $line unless $line =~ /^[\\]/o;
	    $lastpos = tell $fh;
	    $line = <$fh>;
	}

	my $chunk = {};
	$chunk->{filename} = $filename;
	$chunk->{revision} = $revision;
	$chunk->{old_linenumber} = $old_linenumber;
	$chunk->{new_linenumber} = $new_linenumber;
	$chunk->{binary} = 0;
	$chunk->{text} = $diff;
	$chunk->{description} = "";
	$chunk->{repmatch} = $repmatch;
	push @result, $chunk;
    }

    # Restore the file point back to the start of the last unmatched line.
    seek $fh, $lastpos, 0;

    # Return the diff chunks found.
    return @result;
}

1;
