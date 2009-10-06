###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for updating a password.

package Codestriker::Http::Method::UpdatePasswordMethod;

use strict;
use Codestriker::Http::Method;
use Codestriker::Action::UpdatePassword;

@Codestriker::Http::Method::UpdatePasswordMethod::ISA = ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'update_password');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    return $self->{url_prefix} . "?action=" . $self->{action} .
      "&email=" . CGI::escape($args{email});
}

sub requires_authentication {
    return 0;
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::UpdatePassword->process($http_input, $http_output);
}

1;
