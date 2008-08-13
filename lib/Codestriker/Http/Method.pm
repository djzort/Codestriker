###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Base object for all HTTP methods present in the system.
package Codestriker::Http::Method;

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);

# The optional $cgi_style parameter indicates whether the old-style
# CGI URLs are to be generated.  Default is for old-style URLs.
sub new {
	my ($type, $query, $cgi_style) = @_;
	
    my $self = {};
	$self->{query} = $query;
    $self->{cgi_style} = defined $cgi_style ? $cgi_style : 1;
    
    # Determine what prefix is required when using relative URLs.
    # Unfortunately, Netcsape 4.x does things differently to everyone
  	# else.
  	$self->{url_prefix} = $query->url();
   	my $browser = $ENV{'HTTP_USER_AGENT'};
   	if (defined $browser && $browser =~ m%^Mozilla/(\d)% && $1 <= 4) {
		$self->{url_prefix} = $self->{query}->url(-relative=>1);
   	}

    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
	my ($self, %args) = @_;
	
	return undef;
}

# If this query type is recognised, extract the parameters and store them into
# $http_input and return true, otherwise return false.
sub extract_parameters {
	my ($self, $http_input) = @_;
	
	return 0;
}

# Return the handler for this method.
sub execute {
	my ($self, $http_input, $http_output) = @_;
	
	die "execute() method is not implemented";
}

# Utility method for extracting the specified parameter from a URL if it exists.
sub _extract_nice_parameters {
	my ($self, $http_input, %parameters) = @_;
	
	my $path_info = $http_input->{query}->path_info();
	foreach my $nice_parameter (keys %parameters) {
	    if ($path_info =~ m{/$nice_parameter/([^/#]+)}) {
		    $http_input->{$parameters{$nice_parameter}} = CGI::unescape($1);
	    }
	}
}

1;
