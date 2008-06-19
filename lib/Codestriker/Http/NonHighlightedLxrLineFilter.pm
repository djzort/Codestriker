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
sub filter {
    my ($self, $text) = @_;
    
    # If the line is a comment, don't do any processing.  Note this code
    # isn't bullet-proof, but its good enough most of the time.
    $_ = $text;
    return $text if (/^(\s|&nbsp;)*\/\// || 
    				 /^(\s|&nbsp;){0,10}\*/ ||
		             /^(\s|&nbsp;){0,10}\/\*/ ||
		             /^(\s|&nbsp;)*\*\/(\s|&nbsp;)*$/);
    
    # Handle package Java statements.
    if ($text =~ /^(package(\s|&nbsp;)+)([\w\.]+)(.*)$/) {
		return $1 . $self->lxr_ident($3) . $4;
    }
    
    # Handle Java import statements.
    if ($text =~ /^(import(\s|&nbsp;)+)([\w\.]+)\.(\w+)((\s|&nbsp;)*)(.*)$/) {
		return $1 . $self->lxr_ident($3) . "." . $self->lxr_ident($4) . "$5$7";
    }
    
    # Break the string into potential identifiers, and look them up to see
    # if they can be hyperlinked to an LXR lookup.
    my $idhash = $self->{idhash};
    my @data_tokens = split /([_A-Za-z][\w]+)/, $text;
    my $newdata = "";
    my $in_comment = 0;
    my $eol_comment = 0;
    for (my $i = 0; $i <= $#data_tokens; $i++) {
		my $token = $data_tokens[$i];
		if ($token =~ /^[_A-Za-z]/) {
	    	if ($eol_comment || $in_comment) {
				# Currently in a comment, don't LXRify.
				$newdata .= $token;
	    	} elsif ($token eq "nbsp" || $token eq "quot" || $token eq "amp" ||
		    	$token eq "lt" || $token eq "gt") {
		    	# TODO: is this still needed?	
				# HACK - ignore potential HTML entities.  This needs to be
				# done in a smarter fashion later.
				$newdata .= $token;
	    	} else {
				$newdata .= $self->lxr_ident($token);
	    	}
		} else {
	    	$newdata .= $token;
	    	$token =~ s/(\s|&nbsp;)//g;
	    
	    	# Check if we are entering or exiting a comment.
	    	if ($token =~ /\/\//) {
				$eol_comment = 1;
	    	} elsif ($token =~ /\*+\//) {
				$in_comment = 0;
	    	} elsif ($token =~ /\/\*/) {
				$in_comment = 1;
	    	}
		}
    }

    return $newdata;
}

1;
