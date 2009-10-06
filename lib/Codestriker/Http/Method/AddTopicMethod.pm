###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for adding a topic to a project.

package Codestriker::Http::Method::AddTopicMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::AddTopicMethod::ISA = ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'submit_new_topic');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    die "Parameter projectid missing" unless defined $args{projectid};

    return $self->{url_prefix} . "?action=" . $self->{action};
}

# For now don't require authentication so that automated scripts can still
# create topics.  Will need to modify CodestrikerClient.pm so that it can
# take a username/password.
sub requires_authentication {
    return 0;
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::SubmitNewTopic->process($http_input, $http_output);
}

1;
