###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for editing a project.

package Codestriker::Http::Method::EditProjectMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::EditProjectMethod::ISA = ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'edit_project');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, $projectid) = @_;

    return $self->{url_prefix} . "?action=edit_project&projectid=$projectid";
}

sub requires_admin {
    return 1;
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::EditProject->process($http_input, $http_output);
}

1;
