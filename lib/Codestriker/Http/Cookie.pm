###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Collection of routines for maintaining HTTP cookies.

package Codestriker::Http::Cookie;

use strict;

use CGI::Carp 'fatalsToBrowser';

# Prototypes.
sub make( $$$ );
sub get( $$ );
sub get_property( $$$ );

# Cookie attribute to set.
my $COOKIE_NAME = "codestriker_cookie";

# Given a reference to a hash, create a cookie value that can be put into the
# HTTP response header.
sub make($$$) {
    my ($type, $query, $cookie_value_hash_ref) = @_;

    my $cookie_path = $query->url(-absolute=>1);

    return $query->cookie(-name=>"$COOKIE_NAME",
			  -expires=>'+10y',
			  -path=>"$cookie_path",
			  -value=>$cookie_value_hash_ref);
}

# Return the cookie value associated with this HTTP request.
sub get($$) {
    my ($type, $query) = @_;

    return $query->cookie($COOKIE_NAME);
}

# Return the cookie value associated with this HTTP request.
sub get_property($$$) {
    my ($type, $query, $property) = @_;

    if (defined $query->cookie($COOKIE_NAME)) {
	my %cookie = $query->cookie($COOKIE_NAME);
	return (defined $cookie{$property} ? $cookie{$property} : "");
    } else {
	return "";
    }
}
