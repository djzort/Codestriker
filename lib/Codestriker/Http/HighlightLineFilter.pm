###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Line filter for converting tabs to the appropriate number of &nbsp;
# entities.

package Codestriker::Http::HighlightLineFilter;

use strict;

use Codestriker::Http::LineFilter;

@Codestriker::Http::HighlightLineFilter::ISA =
    ("Codestriker::Http::LineFilter");

# Take the desired tabwidth as a parameter.
sub new {
    my ($type, $highlight) = @_;

    my $self = Codestriker::Http::LineFilter->new();
    $self->{highlight} = $highlight;

    return bless $self, $type;
}

# Convert tabs to the appropriate number of &nbsp; entities.
sub _filter {
    my ($self, $text) = @_;

	

    return $text;
}

# Convert tabs to the appropriate number of &nbsp; entities.
sub filter {
    my ($self, $delta) = @_;
    
    $delta->{diff_old_lines} = $self->_filter($delta->{diff_old_lines});
    $delta->{diff_new_lines} = $self->_filter($delta->{diff_new_lines});
}

1;
