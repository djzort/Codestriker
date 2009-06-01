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
use Codestriker::FileParser::BasicDiffUtils;

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
        my $filename;
        my $repmatch;

        # Skip whitespace.
        while (defined($line) &&
               ($line =~ /^\s*$/o || $line =~ /^Version not found/o)) {
            $line = <$fh>;
        }
        return @result unless defined $line;

        # For VSS diffs, the start of the diff block is the "Diffing:" line
        # which contains the filename and version number.  Some diffs may
        # not contain the version number for us.
        if ($line =~ /^Diffing: (.*);(.+)$/o) {
            $filename = $1;
            $revision = $2;
            $repmatch = 1;
        } elsif ($line =~ /^Diffing: (.*)$/o) {
            $filename = $1;
            $revision = $Codestriker::PATCH_REVISION;
            $repmatch = 0;
        } else {
            # Some other weird format.
            return ();
        }

        # The next line will be the "Against:" line, followed by a blank line.
        $line = <$fh>;
        return () unless defined $line && $line =~ /^Against:/o;
        $line = <$fh>;
        return () unless defined $line && $line =~ /^\s*$/o;

        # The next part of the diff will be the old style diff format, or
        # possibly "No differences." if there are no differences.
        $line = <$fh>;
        if ($line !~ /^No differences\./o) {
            my $chunk;
            do
              {
                  my $leading_context = '';
                  my $leading_context_line_count = 0;
                  my $trailing_context = '';
                  my $trailing_context_line_count = 0;
                  if ($line =~ /^\*\*\*\*\*\*\*\*/o ||
                      $line =~ /^ /o) {
                      # Need to record some leading context.
                      $line = <$fh> if $line =~ /^\*\*\*\*\*\*\*\*/o;
                      while ($line =~ /^ (.*)$/o) {
                          $leading_context .= "$1\n";
                          $leading_context_line_count++;
                          $line = <$fh>;
                      }
                  }

                  $chunk = Codestriker::FileParser::BasicDiffUtils
                    ->read_diff_text($fh, $line, $filename, $revision,
                                     $repmatch);
                  if (defined $chunk) {
                      # Check for trailing context.
                      $line = <$fh>;
                      while (defined $line && $line =~ /^ (.*)$/o) {
                          $trailing_context .= "$1\n";
                          $trailing_context_line_count++;
                          $line = <$fh>;
                      }

                      # Adjust the chunk accordingly with the leading and
                      # trailing context.
                      if ($leading_context_line_count > 0) {
                          $chunk->{old_linenumber} -= $leading_context_line_count;
                          $chunk->{new_linenumber} -= $leading_context_line_count;
                          $chunk->{text} = $leading_context . $chunk->{text};
                      }
                      if ($trailing_context_line_count > 0) {
                          $chunk->{text} .= $trailing_context;
                      }
                      push @result, $chunk;
                  }
              } while (defined $chunk && defined $line);
        }

        # Read the next line.
        $line = <$fh> if defined $line;
    }

    # Return the found diff chunks.
    return @result;
}

1;
