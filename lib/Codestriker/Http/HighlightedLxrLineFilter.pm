###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Line filter for linking to LXR for highlighted text.

package Codestriker::Http::HighlightedLxrLineFilter;

use strict;

use Codestriker::Http::LxrLineFilter;

@Codestriker::Http::HighlightedLxrLineFilter::ISA =
    ("Codestriker::Http::LxrLineFilter");

# Replace all variables with the appropriate link to LXR.
sub _filter {
    my ($self, $text) = @_;

	$text =~ s#(<span class="hl kwd">)(.*?)(</span>)#$1 . $self->lxr_ident($2) . $3#geo;
	$text =~ s#(<span class="kwd">)(.*?)(</span>)#$1 . $self->lxr_ident($2) . $3#geo;
	$text =~ s#(>\s*)([^<]+?)<#$1 . $self->_handle_identifiers($2) . '<'#gemo;
    return $text;
}
