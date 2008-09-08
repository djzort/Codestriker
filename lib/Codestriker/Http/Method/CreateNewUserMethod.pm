###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for creating a new user.

package Codestriker::Http::Method::CreateNewUserMethod;

use strict;
use Codestriker::Http::Method;
use Codestriker::Action::CreateNewUser;

@Codestriker::Http::Method::CreateNewUserMethod::ISA = ("Codestriker::Http::Method");

# Generate a URL for this method.
sub url() {
    my ($self, %args) = @_;

    if ($self->{cgi_style}) {
        return $self->{url_prefix} . "?action=create_new_user" .
          (defined $args{feedback} ? "&feedback=" . CGI::escape($args{feedback}) : "");
    } else {
        return $self->{url_prefix} . "/users/create" .
          (defined $args{feedback} ? "/feedback/" . CGI::escape($args{feedback}) : "");
    }
}

sub extract_parameters {
    my ($self, $http_input) = @_;

    my $action = $http_input->{query}->param('action');
    my $path_info = $http_input->{query}->path_info();
    if ($self->{cgi_style} && defined $action && $action eq "create_new_user") {
        $http_input->extract_cgi_parameters();
        return 1;
    } elsif ($path_info eq "/users/create") {
        $self->_extract_nice_parameters($http_input);
        return 1;
    } else {
        return 0;
    }
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::CreateNewUser->process($http_input, $http_output);
}

1;
