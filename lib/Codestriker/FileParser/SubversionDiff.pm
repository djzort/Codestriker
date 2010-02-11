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
        my $entry_type;
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

        # For SVN diffs, the start of the diff block is the Index line.
        # For SVN look diffs, the start of the diff block contains the change type.
        # Also check for presence of property set blocks.
        while ($line =~ /^.*Property changes on: .*$/o) {
            $line = <$fh>;
            return () unless defined $line &&
              $line =~ /^___________________________________________________________________$/o;

            # Keep reading until we either get to the separator line or end of file.
            while (defined $line &&
                   $line !~ /^===================================================================$/o) {
                if ($line =~ /^.*(Index|Added|Modified|Copied|Deleted): (.*)$/o) {
                    $entry_type = $1;
                    $filename = $2;
                }
                $line = <$fh>;
            }

            if (!defined $line) {
                # End of file has been reached, return what we have parsed.
                return @result;
            }
        }

        if ($line =~ /^.*(Index|Added|Modified|Copied|Deleted): (.*)$/o) {
            $entry_type = $1;
            $filename = $2;
            $line = <$fh>;
        }

        # If a blank line is next, this is an entry we can skip, for example, a directory copy.
        next if defined $line && $line =~ /^\s*$/o;

        # The separator line appears next.
        return () unless defined $line && $line =~ /^===================================================================$/o;
        $line = <$fh>;

        # Check if this is a file entry with no content.  If so, skip it.
        next if ! defined $line || $line =~ /^\s*$/o;

        # Check if the delta represents a binary file.
        if ($line =~ /^Cannot display: file marked as a binary type\./o ||
            $line =~ /^\(Binary files differ\)/o) {

            # If it is a new binary file, there will be some lines before
            # the next Index: line, or end of file.  In other cases, it is
            # impossible to know whether the file is being modified or
            # removed, and what revision it is based off.
            $line = <$fh>;
            my $count = 0;
            while (defined $line && $line !~ /^Index|Added|Modified|Deleted|Property changes on:/o) {
                $line = <$fh>;
                $count++;
            }

            my $chunk = {};
            $chunk->{filename} = $filename;
            if ($entry_type eq "Index") {
                $chunk->{revision} = $count > 0 ? $Codestriker::ADDED_REVISION :
                  $Codestriker::PATCH_REVISION;
            } elsif ($entry_type eq "Added") {
                $chunk->{revision} = $Codestriker::ADDED_REVISION;
            } elsif ($entry_type eq "Deleted") {
                $chunk->{revision} = $Codestriker::REMOVED_REVISION;
            } else {
                $chunk->{revision} = $Codestriker::PATCH_REVISION;
            }
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
            if ($line =~ /^\-\-\- .*\s.*\(.*?(\d+)\)/io) {
                $base_revision = $1;
            } elsif ($line !~ /^\-\-\- .*/io) {
                # This appears to be a new entry with no data - construct
                # an appropriate entry.
                my $chunk = {};
                $chunk->{filename} = $filename;
                $chunk->{revision} = $Codestriker::ADDED_REVISION;
                $chunk->{old_linenumber} = -1;
                $chunk->{new_linenumber} = -1;
                $chunk->{binary} = 1;
                $chunk->{text} = "";
                $chunk->{description} = "";
                $chunk->{repmatch} = 1;
                push @result, $chunk;
                next;
            }

            # Make sure the +++ line is present next.
            $line = <$fh>;
            return () unless defined $line;
            if ($line !~ /^\+\+\+ .*/io) {
                return ();
            }

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
