###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Main delegate parser object, which tries a bunch of parsers to determine what
# format the input review is in.  The last resort, is to view it as
# unstructured text, if it is content-type plain/text, otherwise indicate
# an error.

package Codestriker::FileParser::Parser;

use strict;

use FileHandle;
use File::Temp qw/ tempfile /;

use Codestriker::FileParser::CvsUnidiff;
use Codestriker::FileParser::SubversionDiff;
use Codestriker::FileParser::PerforceDescribe;
use Codestriker::FileParser::PerforceDiff;
use Codestriker::FileParser::VssDiff;
use Codestriker::FileParser::PatchUnidiff;
use Codestriker::FileParser::PatchBasicDiff;
use Codestriker::FileParser::ClearCaseSerialDiff;
use Codestriker::FileParser::UnknownFormat;

# Given the content-type and the file handle, try to determine what files,
# lines, revisions and diffs have been submitted in this review.
sub parse ($$$$$$) {
    my ($type, $fh, $content_type, $repository, $topicid,
        $uploaded_filename) = @_;

    # Diffs found.
    my @diffs = ();

    # This is a pain, but to handle diffs produced on a windoze box, which
    # uses \r\n endings, rather than making each parser object take this
    # into account, create a temporary file here which removes them, and
    # that file handle is passed on to the parser objects, so they aren't
    # the wiser.  Note the temporary file is automatically deleted
    # once this function has finished.
    my $tmpfh;
    if (defined $Codestriker::tmpdir && $Codestriker::tmpdir ne "") {
        $tmpfh = tempfile(DIR => $Codestriker::tmpdir);
    } else {
        $tmpfh = tempfile();
    }
    binmode $tmpfh, ':utf8';

    if (!$tmpfh) {
        die "Unable to create temporary parse file: $!";
    }

    binmode $fh;
    my $first_line = 1;
    while (<$fh>) {
        if ($first_line) {
            # Remove the UTF8 BOM if it exists.
            s/^\xEF\xBB\xBF//o;
            $first_line = 0;
        }
        my $line = Codestriker::decode_topic_text($_);
        $line =~ s/\r\n/\n/go;
        print $tmpfh $line;
    }

    # Rewind the file, then let the parsers have at it.
    seek($tmpfh,0,0) ||
      die "Unable to seek to the start of the temporary file: $!";

    # If the file is plain/text, try all of the text parsers.
    if ($content_type eq "text/plain") {

        # Check if it is a CVS unidiff file.
        if ($#diffs == -1) {
            seek($tmpfh, 0, 0) ||
              die "Unable to seek to the start of the temporary file: $!";
            @diffs =
              Codestriker::FileParser::CvsUnidiff->parse($tmpfh,
                                                         $repository);
        }

        # Check if it is a Subversion diff file.
        if ($#diffs == -1) {
            seek($tmpfh, 0, 0) ||
              die "Unable to seek to the start of the temporary file: $!";
            @diffs =
              Codestriker::FileParser::SubversionDiff->parse($tmpfh,
                                                             $repository);
        }

        # Check if it is a Perforce describe file.
        if ($#diffs == -1) {
            seek($tmpfh, 0, 0) ||
              die "Unable to seek to the start of the temporary file: $!";
            @diffs =
              Codestriker::FileParser::PerforceDescribe->parse($tmpfh,
                                                               $repository);
        }

        # Check if it is a Perforce diff file.
        if ($#diffs == -1) {
            seek($tmpfh, 0, 0) ||
              die "Unable to seek to the start of the temporary file: $!";
            @diffs =
              Codestriker::FileParser::PerforceDiff->parse($tmpfh,
                                                           $repository);
        }

        # Check if it is a VSS diff file.
        if ($#diffs == -1) {
            seek($tmpfh, 0, 0) ||
              die "Unable to seek to the start of the temporary file: $!";
            @diffs =
              Codestriker::FileParser::VssDiff->parse($tmpfh,
                                                      $repository);
        }

        # Check if it is a patch unidiff file.
        if ($#diffs == -1) {
            seek($tmpfh, 0, 0) ||
              die "Unable to seek to the start of the temporary file: $!";
            @diffs =
              Codestriker::FileParser::PatchUnidiff->parse($tmpfh,
                                                           $repository);
        }

        # Check if it is a patch basic file.
        if ($#diffs == -1) {
            seek($tmpfh, 0, 0) ||
              die "Unable to seek to the start of the temporary file: $!";
            @diffs =
              Codestriker::FileParser::PatchBasicDiff->parse($tmpfh,
                                                             $uploaded_filename);
        }

        # Check if it is a ClearCase serial diff file.
        if ($#diffs == -1) {
            seek($tmpfh, 0, 0) ||
              die "Unable to seek to the start of the temporary file: $!";
            @diffs =
              Codestriker::FileParser::ClearCaseSerialDiff->parse($tmpfh,
                                                                  $repository);
        }

        # Last stop-gap - the file format is unknown, treat it as a
        # single file with filename "unknown".
        if ($#diffs == -1) {
            if (! defined $uploaded_filename || $uploaded_filename eq '') {
                $uploaded_filename = 'unknown.txt';
            }
            seek($tmpfh, 0, 0) ||
              die "Unable to seek to the start of the temporary file: $!";
            @diffs = Codestriker::FileParser::UnknownFormat->
              parse($tmpfh, $uploaded_filename);
        }
    } elsif ($content_type eq "application/gzip" ||
             $content_type eq "application/x-gzip") {
        # Check if it is a gzip file.

    } elsif ($content_type eq "application/zip" ||
             $content_type eq "application/x-zip") {
        # Check if it is a zip file.
    }

    # Restore the offset back to the start of the file again.
    seek($fh, 0, 0) ||
      die "Unable to seek to the start of the temporary file. $!";

    if (defined $Codestriker::sort_diffs_by_filename &&
        $Codestriker::sort_diffs_by_filename) {
        # Sort the diff chunks by filename, then old linenumber.
        @diffs = sort { $a->{filename} cmp $b->{filename} ||
                          $a->{old_linenumber} <=> $b->{old_linenumber} } @diffs;
    }

    # Only include those files whose extension is not in
    # @Codestriker::exclude_file_types, provided it is defined.
    return @diffs unless defined @Codestriker::exclude_file_types;

    my @trimmed_diffs = ();
    foreach my $curr (@diffs) {
        if ($curr->{filename} =~ /\.([^\.]+)(,v)?$/o) {
            my $ext = $1;
            push @trimmed_diffs, $curr
              unless grep { $_ eq $ext } @Codestriker::exclude_file_types;
        } else {
            # No extension on this file, add the diff in.
            push @trimmed_diffs, $curr;
        }
    }

    # Return the diffs found, if any.
    return @trimmed_diffs;
}

1;

