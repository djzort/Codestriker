###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for viewing the topic text.

package Codestriker::Http::Method::ViewTopicTextMethod;

use strict;
use Carp;
use Codestriker::Http::Method;

@Codestriker::Http::Method::ViewTopicTextMethod::ISA =
  ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'view');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    confess "Parameter topicid missing" unless defined $args{topicid};

    return $self->{url_prefix} . "?action=" . $self->{action} . "&topic=$args{topicid}" .
      (defined $args{updated} ? "&updated=$args{updated}" : "") .
        (defined $args{tabwidth} ? "&tabwidth=$args{tabwidth}" : "") .
          (defined $args{mode} ? "&mode=$args{mode}" : "") .
            (defined $args{fview} ? "&fview=$args{fview}" : "") .
              (defined $args{filenumber} ? "#" . "$args{filenumber}|$args{line}|$args{new}" : "");
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::ViewTopic->process($http_input, $http_output);
}

1;
