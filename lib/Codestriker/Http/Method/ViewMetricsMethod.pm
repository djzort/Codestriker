###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for viewing metrics.

package Codestriker::Http::Method::ViewMetricsMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::ViewMetricsMethod::ISA = ("Codestriker::Http::Method");

# Generate a URL for this method.
sub url() {
    my ($self) = @_;

    if ($self->{cgi_style}) {
        return $self->{url_prefix} . "?action=metrics_report";
    } else {
        return $self->{url_prefix} . "/metrics/view";
    }
}

sub extract_parameters {
    my ($self, $http_input) = @_;

    my $action = $http_input->{query}->param('action');
    my $path_info = $http_input->{query}->path_info();
    if ($self->{cgi_style} && defined $action && $action eq "metrics_report") {
        $http_input->extract_cgi_parameters();
        return 1;
    } elsif ($path_info =~ m{^/metrics/view$}) {
        $self->_extract_nice_parameters($http_input);
        return 1;
    } else {
        return 0;
    }
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    Codestriker::Action::MetricsReport->process($http_input, $http_output);
}

1;
