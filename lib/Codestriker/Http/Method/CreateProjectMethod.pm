###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for creating a project.

package Codestriker::Http::Method::CreateProjectMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::CreateProjectMethod::ISA = ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'create_project');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self) = @_;

    return $self->{url_prefix} . "?action=" . $self->{action};
}

sub requires_admin {
    return 1;
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::CreateProject->process($http_input, $http_output);
}

1;
