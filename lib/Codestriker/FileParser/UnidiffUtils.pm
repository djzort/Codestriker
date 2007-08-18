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
	   $line =~ /^\@\@ \-(\d+)(\,)?(\d+)? \+(\d+)(\,)?(\d+)? \@\@(.*)$/) {
	my $old_linenumber = $1;
	my $number_old_lines = 1;
	$number_old_lines = $3 if defined $3;
	my $new_linenumber = $4;
	my $number_new_lines = 1;
	$number_new_lines = $6 if defined $6;
	my $function_name = $7;
	my $num_matched_old_lines = 0;
	my $num_matched_new_lines = 0;

	if (length($function_name) > 1) {
	    $function_name =~ s/^ //;
	}
	else {
	    $function_name = "";
	}

	# Now read in the diff text until finished.  
	my $diff = "";
	$line = <$fh>;
	while (defined $line) {
	    # Skip lines line "\ No newline at end of file".
	    if ($line !~ /^[\\]/o) {

		# Check if the diff block with the trailing context has been
		# read. Note Perforce diffs can contain empty lines.
		if ($num_matched_old_lines >= $number_old_lines &&
		    $num_matched_new_lines >= $number_new_lines) {
		    last unless $line =~ /^\s*$/o;
		}
		else {
		    if ($line =~ /^\-/o) {
			$num_matched_old_lines++;
		    } elsif ($line =~ /^\+/o) {
			$num_matched_new_lines++;
		    } elsif ($line =~ /^ /o || $line =~ /^$/o) {
			$num_matched_old_lines++;
			$num_matched_new_lines++;
		    }
		}

		# Add the line to the diff chunk.
		$diff .= $line;
	    }

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
	$chunk->{description} = $function_name;
	$chunk->{repmatch} = $repmatch;
	push @result, $chunk;
    }

    # Restore the file point back to the start of the last unmatched line.
    seek $fh, $lastpos, 0;

    # Return the diff chunks found.
    return @result;
}

1;
