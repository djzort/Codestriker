###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for going to the login form.

package Codestriker::Http::Method::LoginMethod;

use strict;
use Codestriker::Http::Method;
use Codestriker::Action::Login;

@Codestriker::Http::Method::LoginMethod::ISA = ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'login');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    return $self->{url_prefix} . "?action=" . $self->{action} .
      (defined $args{redirect} ? "&redirect=" . CGI::escape($args{redirect}) : "") .
        (defined $args{feedback} ? "&feedback=" . CGI::escape($args{feedback}) : "");
}

sub requires_authentication {
    return 0;
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::Login->process($http_input, $http_output);
}

1;
