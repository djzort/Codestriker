###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for creating a topic.

package Codestriker::Http::Method::CreateTopicMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::CreateTopicMethod::ISA = ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'create');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, $obsoletes) = @_;

    return $self->{url_prefix} . "?action=" . $self->{action} .
      (defined $obsoletes ? "&obsoletes=$obsoletes" : "");
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::CreateTopic->process($http_input, $http_output);
}

1;
