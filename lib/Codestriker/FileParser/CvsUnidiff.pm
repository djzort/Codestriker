###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Parser object for reading CVS diffs.  This parser object accepts output
# from either:
#
# cvs diff -uN     or
# cvs rdiff -uN -r TAG1 -r TAG2 MODULENAME
#
# The second command actually produces a patch, but it doesn't contain
# important CVS filename and revision information.

package Codestriker::FileParser::CvsUnidiff;

use strict;
use Codestriker::FileParser::UnidiffUtils;

# Return the array of filenames, revision number, linenumber, whether its
# binary or not, and the diff text.
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

    my $line = <$fh>;
    while (defined($line)) {
	# Values associated with the diff.
	my $revision;
	my $filename = "";
	my $old_linenumber = -1;
	my $new_linenumber = -1;
	my $binary = 0;
	my $repmatch = 0;
	my $diff = "";
	
	# CVS diffs may start with a number of unknown files, which start
	# with a ? character.  These lines can be skipped, as can blank lines.
	# Note, some review text is formed by concatenating multiple
	# cvs diffs together, so the check is done here.  Also, this handles
	# trailing whitespace.
	while (defined($line) && ($line =~ /^\?/o || $line =~ /^\s*$/o)) {
	    $line = <$fh>;
	}
	return @result unless defined $line;

	# For CVS diffs, the start of the diff block is the Index line.
	return () unless defined $line && $line =~ /^Index:/o;
	$line = <$fh>;

	# The separator line appears next, for diffs, but not rdiffs.
	return @result unless defined $line;
	if ($line =~ /^===================================================================$/o) {
	    $line = <$fh>;
	}

	# Now we expect the RCS line, whose filename should include the CVS
	# repository, and if not, it is probably a new file, or it is a
	# cvs rdiff.  Make the match for the repository root case insensitive
	# since different Windoze CVS clients (Cygwin + CvsNT) may return different
	# repository roots with different casing.
	return () unless defined $line;
	if (defined $repository_root &&
	    $line =~ /^RCS file: $repository_root\/(.*),v$/i) {
	    $repmatch = 1;
	    $filename = $1;
	    $line = <$fh>;
	    return () unless defined $line;
	} elsif ($line =~ /^RCS file: (.*)$/o) {
	    $filename = $1;
	    $line = <$fh>;
	    return () unless defined $line;
	}

	# Now we expect the retrieving revision line, unless it is a new or
	# removed file, or a cvs rdiff.
	if ($line =~ /^retrieving revision (.*)$/o) {
	    $revision = $1;
	    $line = <$fh>;
	    return () unless defined $line;
	}

	# If we are doing a diff between two revisions, a second revision
	# line will appear.  Don't care what the value of the second
	# revision is.
	if ($line =~ /^retrieving revision (.*)$/o) {
	    $line = <$fh>;
	}

	# For some rdiffs, if there is a binary file which has changed, no
	# other information is posted, so process the next header.
	next if ($line =~ /^Index:/o);
	
	# Now read in the diff line, followed by the legend lines.  If this is
	# not present, then we know we aren't dealing with a diff file of any
	# kind.
	return () unless $line =~ /^diff/o;
	$line = <$fh>;
	return () unless defined $line;


	# If the diff is empty (since we may have used the -b flag), continue
	# processing the next diff header back around this loop.  Note this is
	# only an issue with cvs diffs.  Ordinary diffs just don't include
	# a diff section if it is blank.
	next if ($line =~ /^Index:/o);

	# Check for binary files being added, changed or removed.
	if ($line =~ /^Binary files \/dev\/null and (.*) differ$/o) {
	    # Binary file has been added.
	    $revision = $Codestriker::ADDED_REVISION;
	    $filename = $1;
	    $binary = 1;
	} elsif ($line =~ /^Binary files (.*) and \/dev\/null differ$/o) {
	    # Binary file has been removed.
	    $revision = $Codestriker::REMOVED_REVISION;
	    $binary = 1;
	} elsif ($line =~ /^Binary files .* and (.*) differ$/o) {
	    # Binary file has been modified.
	    $binary = 1;
	    $filename = $1;
	} elsif ($line =~ /^\-\-\- \/dev\/null/o) {
	    # File has been added.
	    $revision = $Codestriker::ADDED_REVISION;
	} elsif ($line =~ /^\-\-\- nul/o) {
	    # File has been added.
	    $revision = $Codestriker::ADDED_REVISION;
	} elsif ($line =~ /^\-\-\- (.*):(\d+\.[\d\.]+)\t/) {
	    # This matchs a cvs rdiff file, extract the filename and revision.
	    # It is assumed to match the repository specified, although there
	    # is no real way of checking.
	    $filename = $1;
	    $revision = $2;
	    $repmatch = 1;
	} elsif (! $line =~ /^\-\-\-/o) {
	    return ();
	}

	# If its a binary file, add the delta to the list.
	if ($binary) {
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
	} else {
	    # Now expect the +++ line.
	    $line = <$fh>;
	    return () unless (defined $line && $line =~ /^\+\+\+/o);
	    
	    # Check if it is a removed file.
	    if ($line =~ /^\+\+\+ \/dev\/null/o) {
		# File has been removed.
		$revision = $Codestriker::REMOVED_REVISION;
	    }

	    # If it is an added file, and the filename hasn't been extracted
	    # (remote diffs), do so now.
	    if ($revision eq $Codestriker::ADDED_REVISION &&
		$filename eq "" &&
		$line =~ /^\+\+\+ (.*)\t/) {
		$filename = $1;
	    }
	    
	    # Now read in the multiple chunks.
	    my @file_diffs = Codestriker::FileParser::UnidiffUtils->
		read_unidiff_text($fh, $filename, $revision, $repmatch);
	    
	    push @result, @file_diffs;
	}

	# Read the next line.
	$line = <$fh>;
    }

    # Return the found diff chunks.
    return @result;
}
	
1;

    
