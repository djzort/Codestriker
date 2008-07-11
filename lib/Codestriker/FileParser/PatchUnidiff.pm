###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Parser object for reading patch unidiffs.

package Codestriker::FileParser::PatchUnidiff;

use strict;
use Codestriker::FileParser::UnidiffUtils;

# Return the array of filenames, revision number, linenumber and the diff text.
# Return () if the file can't be parsed, meaning it is in another format.
sub parse ($$) {
    my ($type, $fh) = @_;

    # Array of results found.
    my @result = ();

    # Ignore any whitespace at the start of the file.
    my $line = <$fh>;
    while (defined($line)) {

	# Values associated with the diff.
	my $revision = $Codestriker::PATCH_REVISION;
	my $filename = "";
	my $old_linenumber = -1;
	my $new_linenumber = -1;
	my $binary = 0;

	# Skip any heading or trailing whitespace contained in the review
	# text.
	while (defined($line) && $line =~ /^\s*$/) {
	    $line = <$fh>;
	}
	return @result unless defined $line;

	# For unidiffs, the diff line may appear first, but is optional,
	# depending on how the diff was generated.  In any case, the line
	# is ignored.
	if (defined $line && $line =~ /^diff/o) {
	    $line = <$fh>;
	}
	return () unless defined $line;
	
	# Git patches might have an index: line, such as:
	# index b3fc290..d13313f 100644
	if ($line =~ /^index /o) {
		$line = <$fh>;
	}
	return () unless defined $line;
	

        # Need to check for binary file differences.
        # Unfortunately, when you provide the "-N" argument to diff,
        # it doesn't indicate new files or removed files properly.  Without
        # the -N argument, it then indicates "Only in ...".
        if ($line =~ /^Binary files .* and (.*) differ$/ ||
	    $line =~ /^Files .* and (.*) differ$/) {
            $filename = $1;
            $binary = 1;
        } elsif ($line =~ /^Only in (.*): (.*)$/) {
            $filename = "$1/$2";
            $binary = 1;
	} elsif ($line =~ /^\-\-\- \/dev\/null/o) {
	    # File has been added.
	    $revision = $Codestriker::ADDED_REVISION;
	} elsif ($line =~ /^\-\-\- ([^\t]+)/o) {
		# Note git and quilt diffs don't have a tab character unlike normal diffs.
	    $filename = $1;
	} else {
	    return ();
	}
	
	if ($binary == 0) {
	    # Now expect the +++ line.
	    $line = <$fh>;
	    return () unless defined $line;

	    # Check if it is a removed file.
	    if ($line =~ /^\+\+\+ \/dev\/null/o) {
		# File has been removed.
		$revision = $Codestriker::REMOVED_REVISION;
	    } elsif ($line =~ /^\+\+\+ ([^\t]+)/o) {
		$filename = $1;
	    } else {
		return ();
	    }

	    # Extract the diff chunks for this file.
	    my @file_diffs = Codestriker::FileParser::UnidiffUtils->
		read_unidiff_text($fh, $filename, $revision, 0);
	    push @result, @file_diffs;
	} else {
	    my $chunk = {};
	    $chunk->{filename} = $filename;
	    $chunk->{revision} = $revision;
	    $chunk->{old_linenumber} = -1;
	    $chunk->{new_linenumber} = -1;
	    $chunk->{binary} = 1;
	    $chunk->{text} = "";
	    $chunk->{description} = "";
	    $chunk->{repmatch} = 0;
	    push @result, $chunk;
	}

	# Read the next line.
	$line = <$fh>;
    }

    # Return the found diff chunks.
    return @result;
}

1;

    
