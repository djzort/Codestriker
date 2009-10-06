###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for executing the logout action.
package Codestriker::Http::Method::LogoutMethod;

use strict;
use Codestriker::Http::Method;
use Codestriker::Action::Logout;

@Codestriker::Http::Method::LogoutMethod::ISA = ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'logout');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    return $self->{url_prefix} . "?action=" . $self->{action};
}

sub requires_authentication {
    return 1;
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::Logout->process($http_input, $http_output);
}

1;
