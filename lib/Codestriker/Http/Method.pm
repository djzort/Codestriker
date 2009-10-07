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

sub new {
    my ($type, $query, $action) = @_;

    my $self = {};
    $self->{query} = $query;
    $self->{url_prefix} = $query->url();
    $self->{action} = $action;

    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    return undef;
}

# Indicates that this method requires authentication.  If an admin
# user has been specified in codestriker.conf, then assume
# authentication is required.
sub requires_authentication {
    return defined $Codestriker::admin_users;
}

# Indicates that this method can only be executed by an admin.
sub requires_admin {
    return 0;
}

# Indicates if this method can handle the specified http request.
sub can_handle {
    my ($self, $http_input) = @_;

    my $regexp = '^' . $self->{action} . '$';
    return $http_input->{action} =~ m/$regexp/;
}

# Return the handler for this method.
sub execute {
    my ($self, $http_input, $http_output) = @_;

    die "execute() method is not implemented";
}

1;
