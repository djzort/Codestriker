###############################################################################
# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
# All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Parser object for reading patch unidiffs diffs.

package Codestriker::FileParser::PatchUnidiff;

use strict;

# Return the array of filenames, revision number, linenumber and the diff text.
# Return undef if the file can't be parsed, meaning it is in another format.
sub parse ($$) {
    my ($type, $fh) = @_;

    return ();
}

1;

    
