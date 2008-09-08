###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for viewing the topic properties.

package Codestriker::Http::Method::UpdateTopicPropertiesMethod;

use strict;
use Carp;
use Codestriker::Http::Method;

@Codestriker::Http::Method::UpdateTopicPropertiesMethod::ISA = ("Codestriker::Http::Method");

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    if ($self->{cgi_style}) {
        return $self->{url_prefix} . "?action=submit_edit_topic_properties";
    } else {
        confess "Parameter topicid missing" unless defined $args{topicid};
        confess "Parameter projectid missing" unless defined $args{projectid};
        return $self->{url_prefix} . "/project/$args{projectid}/topic/$args{topicid}/properties/update";
    }
}

sub extract_parameters {
    my ($self, $http_input) = @_;

    my $action = $http_input->{query}->param('action');
    my $path_info = $http_input->{query}->path_info();
    if ($self->{cgi_style} && defined $action && $action eq "edit_topic_properties") {
        return 1;
    } elsif ($path_info =~ m{^/project/\d+/topic/\d+/properties}) {
        $self->_extract_nice_parameters($http_input,
                                        project => 'projectid', topic => 'topic');
        return 1;
    } else {
        return 0;
    }
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::SubmitEditTopicProperties->process($http_input, $http_output);
}

1;
