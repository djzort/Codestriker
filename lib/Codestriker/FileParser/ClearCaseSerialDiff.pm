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
sub parse ($$$) {
    my ($type, $fh, $repository) = @_;

    # Retrieve the repository root, and escape back-slashes in the case of
    # a Windows CVS repository, as it is used in regular expressions.
    my $repository_root =
	(defined $repository) ? $repository->getRoot() : undef;
    if (defined $repository_root) {
        $repository_root =~ s/\\/\\\\/g;
    }

    # Array of results found.
    my @result = ();

    # The current filename and revision being tracked.
    my $revision = $Codestriker::PATCH_REVISION;
    my $filename = "";
    my $repmatch = 0;

    # Ignore any whitespace at the start of the file.
    my $line = <$fh>;
    while (defined($line)) {
	# Skip any heading or trailing whitespace contained in the review
	# text, in addition to the "Files are identical" lines, which happen
	# due to the way review texts are generated.
	while (defined($line) &&
	       ($line =~ /^\s*$/o || $line =~ /^Files are identical$/)) {
	    $line = <$fh>;
	}
	return @result unless defined $line;

	# Check if the next fileheader is being read.
	if (defined $line &&
	    $line =~ /^\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*$/o) {

	    # Now read the file/directory that has been modified.
	    $line = <$fh>;
	    return () unless defined $line;
	    
	    if ($line =~ /^\<\<\< file 1\: (.*)\@\@(.*)$/o) {
		$filename = $1;
		$revision = $2;

		# Check if the filename matches the clear case repository.
		# This is very simple for now, but will need to be more
		# sophisticated later.
		if (defined $repository_root &&
		    $filename =~ /^$repository_root[\/\\](.*)$/) {
		    $filename = $1;
		    $repmatch = 1;
		} else {
		    $repmatch = 0;
		}

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
	    elsif ($line =~ /^\<\<\< directory 1\: (.*)\@\@(.*)$/o) {
		# Currently we don't really support directory operations.
		# ClearCase captures added/deleted directories and deleted files as
		# a directory change, but unfortunately added files go straight into
		# the VOB - great.  Try to fidge this so that we treat the directory
		# as a file, where the contents are the diff file itself - better than
		# nothing.
		$filename = $1;
		$revision = $2;

		# Check if the filename matches the clear case repository.
		# This is very simple for now, but will need to be more
		# sophisticated later.
		if (defined $repository_root &&
		    $filename =~ /^$repository_root[\/\\](.*)$/) {
		    $filename = $1;
		}

		# Read the next line which is the local directory.
		$line = <$fh>;
		return () unless
		    defined $line && $line =~ /^\>\>\> directory 2\: .*$/o;
	    
		# Now expect the end of the file header.
		$line = <$fh>;
		return () unless
		    defined $line && $line =~ /^\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*$/o;

		# Keep reading text until there is nothing left for this segment.
		my $text = "";
		$line = <$fh>;
		while (defined $line &&
		       $line !~ /^\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*$/o) {
		    if ($line !~ /^Files are identical$/o) {
			$text .= "+$line";
		    }
		    $line = <$fh>;
		}
		
		# Create the chunk, indicating there is not a repository match, since
		# this is for a directory.
		my $chunk = {};
		$chunk->{filename} = $filename;
		$chunk->{revision} = $revision;
		$chunk->{old_linenumber} = 0;
		$chunk->{new_linenumber} = 0;
		$chunk->{binary} = 0;
		$chunk->{text} = $text;
		$chunk->{description} = "";
		$chunk->{repmatch} = 0;
		push @result, $chunk;

		# Process the next block.
		next;
	    }
	    else {
		# Some unknown format.
		return ();
	    }
	}

	# Read the next diff chunk.
	my $chunk =
	    Codestriker::FileParser::BasicDiffUtils->read_diff_text(
		       $fh, $line, $filename, $revision, $repmatch);
	return () unless defined $chunk;
	push @result, $chunk;

	# Read the next line.
	$line = <$fh>;
    }

    # Return the found diff chunks.
    return @result;
}

1;

    
