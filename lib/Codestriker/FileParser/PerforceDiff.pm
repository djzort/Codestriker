###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Parser object for reading the output for a perforce diff command, such
# as:
#
# p4 diff -du
#

package Codestriker::FileParser::PerforceDiff;

use strict;
use Codestriker::FileParser::UnidiffUtils;

sub _make_chunk ($);
sub _retrieve_file ($$);

# Return the array of filenames, revision number, linenumber, whether its
# binary or not, and the diff text.
# Return () if the file can't be parsed, meaning it is in another format.
sub parse ($$$) {
    my ($type, $fh, $repository) = @_;

    # Skip initial whitespace.
    my $line = <$fh>;
    while (defined($line) && $line =~ /^\s*$/) {
	$line = <$fh>;
    }

    # Array of results found.
    my @result = ();

    # Assume the repository matches this diff, unless we find evidence to
    # the contrary.
    my $repmatch = 1;

    # Now read the actual diff chunks.
    while (defined($line)) {
	if ($line =~ /^==== (.*)\#(\d+) \- .* ==== \((.*)\)$/) {
	    my $filename = $1;
	    my $revision = $2;
	    my $file_type = $3;

	    if ($file_type eq "ubinary" ||
		$file_type eq "binary") {
		# Binary file, skip the next line and add the record in.
		$line = <$fh>;
		my $chunk = {};
		$chunk->{filename} = $filename;
		$chunk->{revision} = $revision;
		$chunk->{old_linenumber} = -1;
		$chunk->{new_linenumber} = -1;
		$chunk->{binary} = 1;
		$chunk->{text} = "";
		$chunk->{description} = "";
		$chunk->{repmatch} = $repmatch;
		push @result, $chunk;
	    }
	    elsif ($file_type eq "text") {
		my @file_diffs = Codestriker::FileParser::UnidiffUtils->
		    read_unidiff_text($fh, $filename, $revision, $repmatch);
		push @result, @file_diffs;
	    }
	    else {
		# Got knows what this is, can't parse it.
		return ();
	    }
	} elsif ($line =~ /^==== (.*)\#(\d+) \-/) {
	    my $filename = $1;
	    my $revision = $2;

	    # Now read the entire diff chunk (it may be empty if the
	    # user hasn't actually modified the file).
	    my @file_diffs = Codestriker::FileParser::UnidiffUtils->
		read_unidiff_text($fh, $filename, $revision, $repmatch);
	    push @result, @file_diffs;
	} else {
	    # Can't parse this file.
	    return ();
	}
	    
	# Now read the next chunk.
	$line = <$fh> if defined $line;
    }

    # Return the found diff chunks.
    return @result;
}

1;
