###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for viewing the topic properties.

package Codestriker::Http::Method::ViewTopicPropertiesMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::ViewTopicPropertiesMethod::ISA = ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'view_topic_properties');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    die "Parameter topicid missing" unless defined $args{topicid};
    die "Parameter projectid missing" unless defined $args{projectid};

    return $self->{url_prefix} . "?action=" . $self->{action} . "&topic=$args{topicid}";
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::ViewTopicProperties->process($http_input, $http_output);
}

1;
