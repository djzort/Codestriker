###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Parser object used when a text file is in an unknown format.  Treat it as a
# single new file with name "unknown".

package Codestriker::FileParser::UnknownFormat;

use strict;

# Return the array of filenames, revision number, linenumber, whether its
# binary or not, and the diff text.
sub parse ($$) {
    my ($type, $fh, $uploaded_filename) = @_;

    # Array of results found.
    my @result = ();

    # Read in all of the data as a single chunk.
    my $text = "";
    while (defined(my $line = <$fh>)) {
        $text .= "+$line";
    }

    my $chunk = {};

    $chunk->{filename} = $uploaded_filename;
    $chunk->{revision} = $Codestriker::ADDED_REVISION;
    $chunk->{old_linenumber} = 0;
    $chunk->{new_linenumber} = 1;
    $chunk->{binary} = 0;
    $chunk->{text} = $text;
    $chunk->{description} = "";
    $chunk->{repmatch} = 0;
    push @result, $chunk;

    return @result;
}

1;
