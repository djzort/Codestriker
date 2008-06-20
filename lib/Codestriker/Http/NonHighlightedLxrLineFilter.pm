###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Line filter for linking to LXR for non-highlighted text.

package Codestriker::Http::NonHighlightedLxrLineFilter;

use strict;

use Codestriker::Http::LxrLineFilter;

@Codestriker::Http::NonHighlightedLxrLineFilter::ISA =
    ("Codestriker::Http::LxrLineFilter");

# Parse the line and produce the appropriate hyperlinks to LXR.
# Currently, this is very Java/C/C++ centric, but it will do for now.
sub _filter {
    my ($self, $text) = @_;

	my $newdata = "";    
	my @lines = split /\n/, $text;
	foreach my $line (@lines) {
		if ($line =~ /^(package(\s|&nbsp;)+)([\w\.]+)(.*)$/) {     
		    # Handle package Java statements.
			$newdata .= $1 . $self->lxr_ident($3) . $4 . "\n";
	    }
    	elsif ($line =~ /^(import(\s|&nbsp;)+)([\w\.]+)\.(\w+)((\s|&nbsp;)*)(.*)$/) { 
		    # Handle Java import statements.
			$newdata .= $1 . $self->lxr_ident($3) . "." . $self->lxr_ident($4) . "$5$7\n";
	    }
    	else {
    		$newdata .= $self->_handle_identifiers($line) . "\n";
		}
    }
    		
    return $newdata;
}

1;
