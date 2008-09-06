###############################################################################
# Copyright (c) 2003 Jason Remillard.  All rights reserved.
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying a metrics report.

package Codestriker::Action::MetricsReport;

use strict;
use Codestriker::Http::Template;
use Codestriker::Model::Topic;
use Codestriker::Model::MetricStats;

# If the input is valid, produce a metrics report.

sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    $http_response->generate_header(reload=>0, cache=>0);

    my $query = $http_response->get_query();

    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    my $vars = {};

    my @users_metrics =
      Codestriker::Model::MetricStats::get_basic_user_metrics();

    # Anti-spam the email addresses.
    foreach my $user (@users_metrics) {
        $user->{name} = Codestriker->filter_email($user->{name});
    }

    $vars->{user_metrics} = \@users_metrics;

    # Get the comment metrics.
    my @comment_metrics =
      Codestriker::Model::MetricStats::get_comment_metrics();
    $vars->{comment_metrics} = \@comment_metrics;
    $vars->{comment_metrics_month_names} =
      $comment_metrics[0]->{results}->[0]->{monthnames};

    # Get the topic metrics.
    my @topic_metrics = Codestriker::Model::MetricStats::get_topic_metrics();
    $vars->{topic_metrics} = \@topic_metrics;
    $vars->{topic_metrics_month_names} = $topic_metrics[0]->{monthnames};

    $vars->{download_url} = $url_builder->metric_report_download_raw_data();

    my $template = Codestriker::Http::Template->new("metricsreport");
    $template->process($vars);

    $http_response->generate_footer();
}

sub process_download($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    print $query->header(-type=>'text/plain',
                         -charset=>"UTF-8",
                         -attachment=>"metrics.csv",
                         -filename=>"metrics.csv");

    my $columns = Codestriker::Model::MetricStats::get_download_headers();

    print join "\t", @{$columns->{base}},@{$columns->{comment}},
      @{$columns->{topic}}, @{$columns->{user}};
    print "\n";

    my @topicids = Codestriker::Model::MetricStats::get_topic_ids();

    foreach my $id (@topicids) {
        my @line = Codestriker::Model::MetricStats::get_raw_metric_data($id->[0], $columns);
        print join "\t", @line;
        print "\n";
    }
}

1;
