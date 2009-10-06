###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for viewing the a topic file.

package Codestriker::Http::Method::ViewTopicFileMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::ViewTopicFileMethod::ISA = ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'view_file');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    die "Parameter topicid missing" unless defined $args{topicid};
    die "Parameter projectid missing" unless defined $args{projectid};

    return $self->{url_prefix} . "?action=" . $self->{action} . "&fn=$args{filenumber}&" .
      "topic=$args{topicid}&new=$args{new}" .
        (defined $args{mode} ? "&mode=$args{mode}" : "") .
          (defined $args{line} ? "#$args{filenumber}|$args{line}|$args{new}" : "");
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::ViewTopicFile->process($http_input, $http_output);
}

1;
