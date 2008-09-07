###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for going to the reset password form.

package Codestriker::Http::Method::ResetPasswordMethod;

use strict;
use Codestriker::Http::Method;
use Codestriker::Action::ResetPassword;

@Codestriker::Http::Method::ResetPasswordMethod::ISA = ("Codestriker::Http::Method");

# Generate a URL for this method.
sub url() {
    my ($self, %args) = @_;

    if ($self->{cgi_style}) {
        return $self->{url_prefix} . "?action=reset_password" .
          "&email=" . CGI::escape($args{email}) .
          "&challenge=" . CGI::escape($args{challenge});
    } else {
        return $self->{url_prefix} . "/user/" . CGI::escape($args{email}) .
          "/password/reset/challenge/" . CGI::escape($args{challenge});
    }
}

sub extract_parameters {
    my ($self, $http_input) = @_;

    my $action = $http_input->{query}->param('action');
    my $path_info = $http_input->{query}->path_info();
    if ($self->{cgi_style} && defined $action && $action eq "reset_password") {
        $http_input->extract_cgi_parameters();
        return 1;
    } elsif ($path_info =~ m{^/user/.*/password/reset/challenge/}) {
        $self->_extract_nice_parameters($http_input,
                                        user => 'email',
                                        challenge => 'challenge');
        return 1;
    } else {
        return 0;
    }
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::ResetPassword->process($http_input, $http_output);
}

1;
