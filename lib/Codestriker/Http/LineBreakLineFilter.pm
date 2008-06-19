###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Line filter for handling line-breaks.
# entities.

package Codestriker::Http::LineBreakLineFilter;

use strict;

use Codestriker::Http::LineFilter;

@Codestriker::Http::LineBreakLineFilter::ISA =
    ("Codestriker::Http::LineFilter");

sub new {
    my ($type) = @_;

    my $self = Codestriker::Http::LineFilter->new();
    return bless $self, $type;
}

# Convert the spaces appropriately for line-breaking.
sub _filter {
    my ($self, $text) = @_;

    # Replace more than one space with the appropriate number of line breaks.
    # Ensure a real space is left there so if necessary, the browser can
    # perform wrapping.    
    $text =~ s/( [ ]+)/' ' . ('&nbsp;' x (length($1)-1))/eog;			

    return $text;
}

# Convert the spaces appropriately for line-breaking.
sub filter {
    my ($self, $delta) = @_;
    
    $delta->{diff_old_lines} = $self->_filter($delta->{diff_old_lines});
    $delta->{diff_new_lines} = $self->_filter($delta->{diff_new_lines});
}

1;
