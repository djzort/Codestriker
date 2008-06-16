###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Base object for all line filter objects to extend from.  A line filter takes
# a line of code and transforms it in some fashion.  

package Codestriker::Http::LineFilter;

use strict;

sub new {
    my $type = shift;
    my $self = {};
    return bless $self, $type;
}

sub filter {
    my ($self, $delta) = @_;
    
    # Default is a no-op.
}

1;

