###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Utility object for reading basic diffs.

package Codestriker::FileParser::BasicDiffUtils;

use strict;

# Read from the file the next basic diff chunk, and return it.
sub read_diff_text($$$$$$) {
    my ($type, $fh, $first_line, $filename, $revision, $repmatch) = @_;

    my $line = $first_line;

    # For this chunk, determine how many old lines and new lines are in
    # the chunk.
    my $old_linenumber = 0;
    my $new_linenumber = 0;
    my $old_length = 0;
    my $new_length = 0;

    if ($line =~ /^(\d+)a(\d+),(\d+)$/o ||
	$line =~ /^\-\-\-\-\-\[after (\d+) inserted(?:\/moved)? (\d+)\-(\d+)(?: \(was at [\d\-]+\))?\]\-\-\-\-\-\s*$/o) {
	# Added multiple lines of text.
	$old_linenumber = $1+1;
	$new_linenumber = $2;
	$new_length = $3 - $2 + 1;
    } elsif ($line =~ /^(\d+)a(\d+)$/o ||
	     $line =~ /^\-\-\-\-\-\[after (\d+) inserted(?:\/moved)? (\d+)(?: \(was at [\d\-]+\))?\]\-\-\-\-\-\s*$/o) {
	# Added a single line of text.
	$old_linenumber = $1+1;
	$new_linenumber = $2;
	$new_length = 1;
    } elsif ($line =~ /^(\d+),(\d+)d(\d+)$/o ||
	     $line =~ /^\-\-\-\-\-\[deleted(?:\/moved)? (\d+)\-(\d+) after (\d+)(?: \(now at [\d\-]+\))?\]\-\-\-\-\-\s*$/o) {
	# Multiple lines deleted.
	$old_linenumber = $1;
	$new_linenumber = $3+1;
	$old_length = $2 - $1 + 1;
    } elsif ($line =~ /^(\d+)d(\d+)$/o ||
	     $line =~ /^\-\-\-\-\-\[deleted(?:\/moved)? (\d+) after (\d+)(?: \(now at [\d\-]+\))?\]\-\-\-\-\-\s*$/o) {
	# Single line deleted.
	$old_linenumber = $1;
	$new_linenumber = $2+1;
	$old_length = 1;
    } elsif ($line =~ /^(\d+),(\d+)c(\d+),(\d+)$/o ||
	     $line =~ /^\-\-\-\-\-\[(\d+)\-(\d+) changed to (\d+)\-(\d+)\]\-\-\-\-\-\s*$/o) {
	# Multiple text lines changed.
	$old_linenumber = $1;
	$new_linenumber = $3;
	$old_length = $2 - $1 + 1;
	$new_length = $4 - $3 + 1;
    } elsif ($line =~ /^(\d+)c(\d+),(\d+)$/o ||
	     $line =~ /^\-\-\-\-\-\[(\d+) changed to (\d+)\-(\d+)\]\-\-\-\-\-\s*$/o) {
	# Multiple source lines changed to single line.
	$old_linenumber = $1;
	$new_linenumber = $2;
	$old_length = 1;
	$new_length = $3 - $2 + 1;
    } elsif ($line =~ /^(\d+),(\d+)c(\d+)$/o ||
	     $line =~ /^\-\-\-\-\-\[(\d+)\-(\d+) changed to (\d+)\]\-\-\-\-\-\s*$/o) {
	# Single source line changed to multiple lines.
	$old_linenumber = $1;
	$new_linenumber = $3;
	$old_length = $2 - $1 + 1;
	$new_length = 1;
    } elsif ($line =~ /^(\d+)c(\d+)$/o ||
	     $line =~ /^\-\-\-\-\-\[(\d+) changed to (\d+)\]\-\-\-\-\-\s*$/o) {
	# Single line changed to another line.
	$old_linenumber = $1;
	$new_linenumber = $2;
	$old_length = 1;
	$new_length = 1;
    } else {
	# Some other file format.
	return undef;
    }
    
    # The chunk in unidiff format.
    my $chunk_text = "";
    
    # First read the old lines, if any.
    for (my $i = 0; $i < $old_length; $i++) {
	$line = <$fh>;
	if (defined $line && $line =~ /^\< (.*)$/) {
	    $chunk_text .= "-${1}\n";
	} else {
	    # Some other format.
	    return undef;
	}
    }
    
    # If there is both old and new text, read the separator line.
    # Note bloody VSS for some versions will put the --- at the end of
    # the previous line rather than on a new line!
    if ($old_length > 0 && $new_length > 0) {
	my $previous_line = $line;
	my $pos = $fh->getpos;
	$line = <$fh>;
	return undef unless defined $line;
	if ($line !~ /^\-\-\-$/o && $chunk_text =~ /^(.*)\-\-\-$/os) {
	    # Stupid VSS diff format, chop off the seperator characters
	    # and move the file pointer back.
	    $chunk_text = "$1\n";
	    $fh->setpos($pos);
	} elsif ($line !~ /^\-\-\-$/o) {
	    # Didn't match standard separator, some other format.
	    return undef;
	}
    }
    
    # Now read the new lines, if any.
    for (my $i = 0; $i < $new_length; $i++) {
	$line = <$fh>;
	if (defined $line && $line =~ /^\> (.*)$/) {
	    $chunk_text .= "+${1}\n";
	} else {
	    # Some other format.
	    return undef;
	}
    }
    
    # Now create the chunk object, and return it.
    my $chunk = {};
    $chunk->{filename} = $filename;
    $chunk->{revision} = $revision;
    $chunk->{old_linenumber} = $old_linenumber;
    $chunk->{new_linenumber} = $new_linenumber;
    $chunk->{binary} = 0;
    $chunk->{text} = $chunk_text;
    $chunk->{description} = "";
    $chunk->{repmatch} = $repmatch;

    return $chunk;
}

1;
