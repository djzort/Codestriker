###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for updating the topic metrics.

package Codestriker::Http::Method::UpdateTopicMetricsMethod;

use strict;
use Carp;
use Codestriker::Http::Method;

@Codestriker::Http::Method::UpdateTopicMetricsMethod::ISA = ("Codestriker::Http::Method");

# Generate a URL for this method.
sub url() {
    my ($self, %args) = @_;

    if ($self->{cgi_style}) {
        return $self->{url_prefix} . "?action=edit_topic_metrics";
    } else {
        confess "Parameter topicid missing" unless defined $args{topicid};
        confess "Parameter projectid missing" unless defined $args{projectid};
        return $self->{url_prefix} . "/project/$args{projectid}/topic/$args{topicid}/metrics/update";
    }
}

sub extract_parameters {
    my ($self, $http_input) = @_;

    my $action = $http_input->{query}->param('action');
    my $path_info = $http_input->{query}->path_info();
    if ($self->{cgi_style} && defined $action && $action eq "edit_topic_metrics") {
        $http_input->extract_cgi_parameters();
        return 1;
    } elsif ($path_info =~ m{^/project/\d+/topic/\d+/metrics/update}) {
        $self->_extract_nice_parameters($http_input,
                                        project => 'projectid', topic => 'topic');
        return 1;
    } else {
        return 0;
    }
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::SubmitEditTopicMetrics->process($http_input, $http_output);
}

1;
