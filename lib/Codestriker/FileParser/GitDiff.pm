###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Parser object for reading git diffs

package Codestriker::FileParser::GitDiff;

use strict;
use Switch;
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
        my $revision;
        my $filename = "";
        my $old_linenumber = -1;
        my $new_linenumber = -1;
        my $binary = 0;

        # Original and patched blob hashes
        my $blob1;
        my $blob2;

        # Is the file created by the patch?
        my $newfile = 0;
        # Are we finished reading the git diff header?
        my $header_done = 0;
        # Could the header be the whole diff (e.g. rename)?
        my $header_is_diff = 0;
        # Are we done with this chunk of the diff?
        my $diff_done = 0;

        # Skip any heading or trailing whitespace contained in the review
        # text.
        while (defined($line) && $line =~ /^\s*$/) {
            $line = <$fh>;
        }
        return @result unless defined $line;

        # Git diffs start with diff --git...
        return () unless $line =~ /^diff --git/o;

        # Git patches contain header lines for file operations.
        # The header is ended by the index line, the next diff, or eof
        while (! $header_done) {
            $line = <$fh>;
            if (defined $line) {
                switch ($line) {
                    case /^rename from (.*)/ {
                        $filename = $1;
                        $line = <$fh>;
                        return () unless defined $line && $line =~ /^rename to/;
                        $header_is_diff = 1;
                    }
                    case /^copy from (.*)/ {
                        $filename = $1;
                        $line = <$fh>;
                        return () unless defined $line && $line =~ /^copy to/;
                        $header_is_diff = 1;
                    }
                    case /^old mode/ {
                        $line = <$fh>;
                        return () unless defined $line && $line =~ /^new mode/;
                        $header_is_diff = 1;
                    }
                    case /^deleted file mode/ { $header_is_diff = 1 }
                    case /^new file mode/ { $newfile = 1 ; $header_is_diff = 1 }
                    case /^diff --git/ { $header_done = 1 ; $diff_done = 1 }
                    case /^index/ { $header_done = 1 }
                    else {
                        if ($line !~ /^(?:dis|)similarity index/) {
                            return ();
                        }
                    }
                }
            } else {
                if ($header_is_diff) {
                    $header_done = 1;
                } else {
                    return ();
                }
            }
        }
        last unless defined $line;
        if ($diff_done) {
            next;
        }

        # Git patches have an "index <hash>..<hash>" line
        return () unless $line =~ /^index ([0-9a-f]+)\.\.([0-9a-f]+)/;
        # If the patch creates the file, treat the patched version (second blob
        # hash) as original. Otherwise, the first blob hash is the original.
        $blob1 = $1;
        $blob2 = $2;
        $revision = ($newfile) ? $blob2 : $blob1;
        $line = <$fh>;
        return () unless defined $line;

        # Need to check for binary file differences.
        if ($line =~ /^Binary files (?:\/|)[^\/]*\/(.*) and (?:\/|)[^\/]*\/(.*) differ$/ ) {
            $filename = ($newfile) ? $2 : $1;
            $binary = 1;
        } elsif ($line =~ /^\-\-\- (?:\/|)([^\t\n\/]+)\/([^\t\n]+)/o) {
            # Get the filename if it's not a new file
            if (! $newfile) {
                $filename = $2;
            }
        } else {
            return ();
        }

        if ($binary == 0) {
            # Now expect the +++ line.
            $line = <$fh>;
            return () unless defined $line;

            # Get the filename if it's a new file
            if ($line =~ /^\+\+\+ (?:\/|)([^\t\n\/]+)\/([^\t\n]+)/o) {
                if ($newfile) {
                    $filename = $2;
                }
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


