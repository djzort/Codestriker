###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for going to the reset password form.

package Codestriker::Http::Method::NewPasswordMethod;

use strict;
use Codestriker::Http::Method;
use Codestriker::Action::NewPassword;

@Codestriker::Http::Method::NewPasswordMethod::ISA = ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'new_password');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    return $self->{url_prefix} . "?action=" . $self->{action} .
      "&email=" . CGI::escape($args{email}) .
        "&challenge=" . CGI::escape($args{challenge});
}

sub requires_authentication {
    return 0;
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::NewPassword->process($http_input, $http_output);
}

1;
