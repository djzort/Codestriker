###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for authenticating a user.

package Codestriker::Http::Method::AuthenticateMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::AuthenticateMethod::ISA = ("Codestriker::Http::Method");

# Generate a URL for this method.
sub url() {
    my ($self, %args) = @_;

    if ($self->{cgi_style}) {
        return $self->{url_prefix} . "?action=authenticate";
    } else {
        return $self->{url_prefix} . "/login/authenticate";
    }
}

sub extract_parameters {
    my ($self, $http_input) = @_;

    my $action = $http_input->{query}->param('action');
    my $path_info = $http_input->{query}->path_info();
    if ($self->{cgi_style} && defined $action && $action eq "authenticate") {
        $http_input->extract_cgi_parameters();
        return 1;
    } elsif ($path_info =~ m{^/login/authenticate}) {
        $self->_extract_nice_parameters($http_input);
        return 1;
    } else {
        return 0;
    }
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::Authenticate->process($http_input, $http_output);
}

1;
