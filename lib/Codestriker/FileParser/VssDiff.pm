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
	while (defined($line) && $line =~ /^\s*$/o) {
	    $line = <$fh>;
	}
	return @result unless defined $line;

	# For VSS diffs, the start of the diff block is the Index line.
	return () unless defined $line && $line =~ /^Index:/o;

	# Determine if this chunk represents a binary file.
	$binary = 1 if $line =~ /^Index: binary/o;

	# Determine if this chunk is a new file.
	if ($binary) {
	    if ($line =~ /^Index: binary added/o) {
		$revision = $Codestriker::ADDED_REVISION;
		chop $line;
		$line .= "; 0\n";
	    } elsif ($line =~ /^Index: binary removed/o) {
		$revision = $Codestriker::REMOVED_REVISION;
	    } else {
		# Extract the revision number for this modified binary file.
		return () unless 
		    $line =~ /^Index: binary modified \$.*; (\d+)$/o;
		$revision = $1;
	    }
	}
	else {
	    if ($line =~ /^Index: added/o) {
		$revision = $Codestriker::ADDED_REVISION;
		chop $line;
		$line .= "; 0\n";
	    } elsif ($line =~ /^Index: removed/o) {
		$revision = $Codestriker::REMOVED_REVISION;
	    } else {
		# Extract the revision number for this modified file.
		return () unless
		    $line =~ /^Index: modified \$.*; (\d+)$/o;
		$revision = $1;
	    }
	}

	# Extract the filename part off the line.  Note for added files, an
	# artifical revision number has been appended to make life easier.
	return () unless $line =~ /^Index: .* \$\/(.*);/o;
	$filename = $1;

	my $chunk = {};
	$chunk->{filename} = $filename;
	$chunk->{revision} = $revision;
	$chunk->{old_linenumber} = -1;
	$chunk->{new_linenumber} = -1;
	$chunk->{binary} = $binary;
	$chunk->{repmatch} = 1;
	$chunk->{description} = "";
	$chunk->{text} = "";

	# Read the diff chunks.
	$line = <$fh>;
	if ($binary) {
	    # For a binary file, there is nothing more to read.  Add the chunk
	    # to the result list.
	    push @result, $chunk;
	} else {
	    return () unless $line =~ /^\-\-\-/o;
	    $line = <$fh>;
	    return () unless $line =~ /^\+\+\+/o;

	    # Now parse the unidiff chunks.
	    my @file_diffs = Codestriker::FileParser::UnidiffUtils->
		read_unidiff_text($fh, $filename, $revision, 1);
	    push @result, @file_diffs;

	    # Read the next line so the loop can continue processing.
	    $line = <$fh>;
	}
    }

    # Return the found diff chunks.
    return @result;
}
	
1;
