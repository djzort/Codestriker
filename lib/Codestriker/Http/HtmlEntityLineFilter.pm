###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Line filter for encoding HTML entities correctly.

package Codestriker::Http::HtmlEntityLineFilter;

use strict;

use Codestriker::Http::LineFilter;

@Codestriker::Http::HtmlEntityLineFilter::ISA =
    ("Codestriker::Http::LineFilter");

sub new {
    my $type = shift;

    my $self = Codestriker::Http::LineFilter->new();
    return bless $self, $type;
}

# Escape all HTML entities so that they are displayed correctly.
sub _filter {
    my ($self, $text) = @_;
    return HTML::Entities::encode($text);
}

1;

