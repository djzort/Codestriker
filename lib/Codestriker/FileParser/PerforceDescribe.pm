###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Parser object for reading the output for a perforce describe command, such
# as:
#
# p4 describe -du <<changenumber>>
#
# Still need to handle binary files mentioned in the TOC.

package Codestriker::FileParser::PerforceDescribe;

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

    # The table of contents entries.
    my @toc = ();

    # Assume the repository matches this diff, unless we find evidence to
    # the contrary.
    my $repmatch = 1;

    # Check if this is indeed output from a p4 describe command, by looking
    # first for the typical header present.
    return () unless defined($line);
    return () unless defined($line) && $line =~ /^Change \d+ by .* on .*/;

    # Skip the lines up to the table of contents.
    $line = <$fh>;
    while (defined($line) && $line !~ /^\.\.\./) {
	$line = <$fh>;
	return () unless defined $line;
    }

    # Now read the initial table of contents entries.  For added or
    # removed files, we actually need to fetch the text from the
    # repository, as it isn't included in the text of the diff,
    # unlike CVS.
    while (defined($line) && $line =~ /^\.\.\. (.*)\#(\d+) (.*)$/) {
	my $entry = {};
	$entry->{filename} = $1;
	$entry->{revision} = $2;
	$entry->{change_type} = $3;
	$entry->{repmatch} = 1;
	$entry->{old_linenumber} = 0;
	$entry->{new_linenumber} = 0;
	$entry->{text} = "";
	if ($entry->{change_type} eq 'add') {
	    _retrieve_file($entry, $repository);
	} elsif ($entry->{change_type} eq 'delete') {
	    # Need to retrieve the text of the previous revision number,
	    # as the current one is empty.
	    $entry->{revision}--;
	    _retrieve_file($entry, $repository);
	    $entry->{revision}++;
	} else {
	    # Assume it is an edit, nothing else to do, as the diffs
	    # will be included below.
	}
	
	# Add this to the table of contents array.
	push @toc, $entry;
	
	$line = <$fh>;
	return () unless defined $line;
    }

    # Skip the lines until the first diff chunk.
    while (defined($line) && $line !~ /^==== /) {
	$line = <$fh>;
	return () unless defined $line;
    }

    # Now read the actual diff chunks.  Any entries not here will be added
    # or removed files, the text of which has already (should) have been
    # retrieved from the repository.
    my $toc_index = 0;
    while (defined($line) && $line =~ /^====/) {
	# Read the next diff chunk.
	return () unless $line =~ /^==== (.*)\#(\d+) \((.*)\) ====$/;
	my $filename = $1;
	my $revision = $2;
	my $filetype = $3;

	# Check if there are any outstanding added/removed entries from the
	# toc that need to be processed first.
	my $entry = $toc[$toc_index];
	while ($entry->{filename} ne $filename) {
	    my $chunk = _make_chunk($entry);
	    push @result, $chunk;

	    # Check the next TOC entry, if any.
	    last if ($toc_index >= $#toc);

	    $toc_index++;
	    $entry = $toc[$toc_index];
	}

	# Skip the next blank line before the unidiff.
	$line = <$fh>;
	next unless defined $line;

	if ($filetype eq "text") {
	    # Now read the entire diff chunk.
	    # Note there may be an optional '---' and '+++' lines
	    # before the chunk.
	    my $lastpos = tell $fh;
	    if (<$fh> !~ /^\-\-\-/ || <$fh> !~ /^\+\+\+/) {
		# Move the file pointer back.
		seek $fh, $lastpos, 0;
	    }

	    my @file_diffs = Codestriker::FileParser::UnidiffUtils->
		read_unidiff_text($fh, $filename, $revision, $repmatch);
	    push @result, @file_diffs;
	} else {
	    # Assume it is a binary file, initialise the chunk from the
	    # TOC entry, and flag it as binary.
	    my $chunk = _make_chunk($entry);
	    $chunk->{binary} = 1;
	    push @result, $chunk;
	}

	# Move on to the next entry in the TOC.
	$toc_index++;

	# Skip the next blank line before the next chunk.
	$line = <$fh>;
    }

    # Finally, add any remaining TOC netries that are unaccounted for.
    while ($toc_index <= $#toc) {
	my $chunk = _make_chunk($toc[$toc_index]);
	push @result, $chunk;
	$toc_index++;
    }

    # Return the found diff chunks.
    return @result;
}

# Make an initial chunk from a toc entry.
sub _make_chunk ($) {
    my ($entry) = @_;

    my $chunk = {};
    $chunk->{filename} = $entry->{filename};
    $chunk->{revision} = $entry->{revision};
    $chunk->{old_linenumber} = $entry->{old_linenumber};
    $chunk->{new_linenumber} = $entry->{new_linenumber};
    $chunk->{binary} = 0;
    $chunk->{text} = $entry->{text};
    $chunk->{description} = "";
    $chunk->{repmatch} = $entry->{repmatch};
    return $chunk;
}

# Retrieve the text specified in $entry from the repository.
sub _retrieve_file ($$) {
    my ($entry, $repository) = @_;

    eval {
	my $added = $entry->{change_type} eq 'add';
	my @text = ();
	$repository->retrieve($entry->{filename}, $entry->{revision},
			      \@text);
	if ($#text >= 0) {
	    if ($added) {
		$entry->{new_linenumber} = $#text;
	    } else {
		$entry->{old_linenumber} = $#text;
	    }
	    for (my $i = 1; $i <= $#text; $i++) {
		$entry->{text} .= ($added ? "+" : "-") . $text[$i] . "\n";
	    }
	}
    };
    if ($@) {
	# Problem retrieving text, assume there is no repository match.
	$entry->{repmatch} = 0;
    }
}

1;
