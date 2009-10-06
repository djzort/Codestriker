###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for downloading the topic text.

package Codestriker::Http::Method::DownloadTopicTextMethod;

use strict;
use Carp;
use Codestriker::Http::Method;

@Codestriker::Http::Method::DownloadTopicTextMethod::ISA =
  ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'download');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    confess "Parameter topicid missing" unless defined $args{topicid};

    return $self->{url_prefix} . "?action=download&topic=$args{topicid}";
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::DownloadTopic->process($http_input, $http_output);
}

1;
