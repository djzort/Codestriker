###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Parser object for reading Subversion diffs.

package Codestriker::FileParser::SubversionDiff;

use strict;
use Codestriker::FileParser::UnidiffUtils;

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
	my $filename = "";
	my $old_linenumber = -1;
	my $new_linenumber = -1;
	my $binary = 0;
	my $diff = "";

	# Skip whitespace.
	while (defined($line) && $line =~ /^\s*$/) {
	    $line = <$fh>;
	}
	return @result unless defined $line;

	# For SVN diffs, the start of the diff block is the Index line.
	return () unless defined $line && $line =~ /^Index: (.*)$/o;
	$filename = $1;
	$line = <$fh>;

	# The separator line appears next.
	return () unless defined $line && $line =~ /^===================================================================$/;
	$line = <$fh>;

	# Check if the delta represents a binary file.
	if ($line =~ /^Cannot display: file marked as a binary type\./) {
	    # The next line indicates the mime type.
	    $line = <$fh>;
	    return () unless defined $line;
	    return () unless $line =~ /^svn:mime\-type/;

	    # If it is a new binary file, there will be some lines before
	    # the next Index: line, or end of file.  In other cases, it is
	    # impossible to know whether the file is being modified or
	    # removed, and what revision it is based off.
	    $line = <$fh>;
	    my $count = 0;
	    while (defined $line && $line !~ /^Index:/) {
		$line = <$fh>;
		$count++;
	    }

	    my $chunk = {};
	    $chunk->{filename} = $filename;
	    $chunk->{revision} = $count > 0 ? $Codestriker::ADDED_REVISION :
		$Codestriker::PATCH_REVISION;
	    $chunk->{old_linenumber} = -1;
	    $chunk->{new_linenumber} = -1;
	    $chunk->{binary} = 1;
	    $chunk->{text} = "";
	    $chunk->{description} = "";
	    $chunk->{repmatch} = 1;
	    push @result, $chunk;
	} else {
	    # Try and read the base revision this change is against,
	    # while handling new and removed files.
	    my $base_revision = -1;
	    if ($line =~ /^\-\-\- .*\s\(revision (\d+)\)/) {
		$base_revision = $1;
	    } elsif ($line !~ /^\-\-\- .*\s\(working copy\)/) {
		return ();
	    }

	    # Make sure the +++ line is present next.
	    $line = <$fh>;
	    return () unless defined $line;
	    return () unless $line =~ /^\+\+\+ .*\s\(working copy\)/;

	    # Now parse the unidiff chunks.
	    my @file_diffs = Codestriker::FileParser::UnidiffUtils->
		read_unidiff_text($fh, $filename, $base_revision, 1);
	    
	    # If $base_revision is -1, and old_linenumber is 0, then
	    # the file is added.  If $base_revision is -1, and
	    # new_linenumber is 0, then the file is removed.  Update
	    # any chunks to indicate this.
	    if ($base_revision == -1) {
		for (my $i = 0; $i <= $#file_diffs; $i++) {
		    my $delta = $file_diffs[$i];
		    if ($delta->{old_linenumber} == 0) {
			$delta->{revision} = $Codestriker::ADDED_REVISION;
		    } elsif ($delta->{new_linenumber} == 0) {
			$delta->{revision} = $Codestriker::REMOVED_REVISION;
		    }
		}
	    }
		
	    push @result, @file_diffs;

	    # Read the next line.
	    $line = <$fh>;
	}
    }

    # Return the found diff chunks.
    return @result;
}
	
1;
