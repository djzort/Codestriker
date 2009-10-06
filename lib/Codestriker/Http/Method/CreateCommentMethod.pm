###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for adding a comment to a topic.

package Codestriker::Http::Method::CreateCommentMethod;

use strict;
use Carp;
use Codestriker::Http::Method;

@Codestriker::Http::Method::CreateCommentMethod::ISA = ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'edit');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    confess "Parameter topicid missing" unless defined $args{topicid};

    return $self->{url_prefix} . "?action=" . $self->{action} . "&topic=$args{topicid}" .
      (defined $args{filenumber} && $args{filenumber} ne "" ?
       "&fn=$args{filenumber}&line=$args{line}&new=$args{new}" : "") .
        (defined $args{anchor} ? "&a=$args{anchor}" : "") .
          (defined $args{context} ? "&context=$args{context}" : "");
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::EditComment->process($http_input, $http_output);
}

1;
