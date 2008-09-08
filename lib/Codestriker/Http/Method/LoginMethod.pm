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

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    if ($self->{cgi_style}) {
        return $self->{url_prefix} . "?action=login" .
          (defined $args{redirect} ? "&redirect=" . CGI::escape($args{redirect}) : "") .
            (defined $args{feedback} ? "&feedback=" . CGI::escape($args{feedback}) : "");
    } else {
        return $self->{url_prefix} . "/login/form" .
          (defined $args{redirect} ? "/redirect/" . CGI::escape($args{redirect}) : "") .
            (defined $args{feedback} ? "/feedback/" . CGI::escape($args{feedback}) : "");
    }
}

sub extract_parameters {
    my ($self, $http_input) = @_;

    my $action = $http_input->{query}->param('action');
    my $path_info = $http_input->{query}->path_info();
    if ($self->{cgi_style} && defined $action && $action eq "login") {
        return 1;
    } elsif ($path_info =~ m{^/login/form}) {
        $self->_extract_nice_parameters($http_input,
                                        redirect => 'redirect',
                                        feedback => 'feedback');
        return 1;
    } else {
        return 0;
    }
}

sub requires_authentication {
    return 0;
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::Login->process($http_input, $http_output);
}

1;
