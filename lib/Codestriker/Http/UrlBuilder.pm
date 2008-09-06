###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Collection of routines for building codestriker URLs.

package Codestriker::Http::UrlBuilder;

use strict;
use CGI;

use Codestriker::Http::Method;
use Codestriker::Http::Method::ListTopicsMethod;
use Codestriker::Http::Method::CreateTopicMethod;
use Codestriker::Http::Method::ViewTopicTextMethod;
use Codestriker::Http::Method::ViewTopicCommentsMethod;
use Codestriker::Http::Method::ViewTopicFileMethod;
use Codestriker::Http::Method::ViewTopicMetricsMethod;
use Codestriker::Http::Method::ViewTopicPropertiesMethod;
use Codestriker::Http::Method::AddCommentMethod;
use Codestriker::Http::Method::AddTopicMethod;
use Codestriker::Http::Method::CreateProjectMethod;
use Codestriker::Http::Method::DownloadMetricsMethod;
use Codestriker::Http::Method::DownloadTopicTextMethod;
use Codestriker::Http::Method::EditProjectMethod;
use Codestriker::Http::Method::ListProjectsMethod;
use Codestriker::Http::Method::SearchTopicsMethod;
use Codestriker::Http::Method::SubmitSearchTopicsMethod;
use Codestriker::Http::Method::StaticResourcesMethod;
use Codestriker::Http::Method::ViewMetricsMethod;
use Codestriker::Http::Method::UpdateTopicPropertiesMethod;
use Codestriker::Http::Method::UpdateTopicMetricsMethod;
use Codestriker::Http::Method::UpdateCommentMetricsMethod;
use Codestriker::Http::Method::UpdateTopicStateMethod;

# Constructor for this class.
sub new {
    my ($type, $query) = @_;
    my $self = {};

    $self->{query} = $query;
    $self->{cgi_style} = defined $Codestriker::cgi_style ? $Codestriker::cgi_style : 1;

    # Determine what prefix is required when using relative URLs.
    # Unfortunately, Netcsape 4.x does things differently to everyone
    # else.
    $self->{url_prefix} = $query->url();
    my $browser = $ENV{'HTTP_USER_AGENT'};
    if (defined $browser && $browser =~ m%^Mozilla/(\d)% && $1 <= 4) {
        $self->{url_prefix} = $self->{query}->url(-relative=>1);
    }

    # Check if the HTML files are accessible via another URL (required for
    # sourceforge deployment).  Check $Codestriker::codestriker_css.
    my $htmlurl;
    if (defined $Codestriker::codestriker_css &&
        $Codestriker::codestriker_css ne "" &&
        $Codestriker::codestriker_css =~ /[\/\\]/o) {
        $htmlurl = $Codestriker::codestriker_css;
        $htmlurl =~ s/\/.+?\.css//;
    } else {
        # Standard Codestriker deployment.
        $htmlurl = $self->{url_prefix};
        $htmlurl =~ s/codestriker\/codestriker\.pl/codestrikerhtml/;
    }
    $self->{htmldir} = $htmlurl;

    return bless $self, $type;
}

# Create the URL for viewing a topic.
sub view_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::ViewTopicTextMethod->new($self->{query})->url(%args);
}

# Create the URL for downloading the topic text.
sub download_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::DownloadTopicTextMethod->new($self->{query})->url(%args);
}

# Create the URL for creating a topic.
sub create_topic_url {
    my ($self, $obsoletes) = @_;
    return Codestriker::Http::Method::CreateTopicMethod->new($self->{query})->url($obsoletes);
}

# Create the URL for adding a topic to a project.
sub add_topic_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::AddTopicMethod->new($self->{query})->url(%args);
}

# Create the URL for editing a topic.
sub edit_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::CreateCommentMethod->new($self->{query})->url(%args);
}

# Create the URL for viewing a new file.
sub view_file_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::ViewTopicFileMethod->new($self->{query})->url(%args);
}

# Create the URL for the search page.
sub search_url {
    my ($self) = @_;
    return Codestriker::Http::Method::SearchTopicsMethod->new($self->{query})->url();
}

# The submit search URL.
sub submit_search_url {
    my ($self) = @_;
    return Codestriker::Http::Method::SubmitSearchTopicsMethod->new($self->{query})->url();
}

# Create the URL for the documentation page.
sub doc_url {
    my ($self) = @_;
    return Codestriker::Http::Method::StaticResourcesMethod->new($self->{query})->url();
}

# Create the URL for listing the topics (and topic search). See
# _list_topics_url for true param list.
sub list_topics_url {
    my ($self, %args) = @_;

    $args{action} = "list_topics";
    return $self->_list_topics_url(%args);
}

# Create the URL for listing the topics (and topic search) via RSS. See
# _list_topics_url for true param list.
sub list_topics_url_rss {
    my ($self, %args) = @_;

    $args{action} = "list_topics_rss";
    return $self->_list_topics_url(%args);
}

# Create the URL for listing the topics.
sub _list_topics_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::ListTopicsMethod->new($self->{query})->url(%args);
}


# Construct a URL for editing a specific project.
sub edit_project_url {
    my ($self, $projectid) = @_;
    return Codestriker::Http::Method::EditProjectMethod->new($self->{query})->url($projectid);
}

# Construct a URL for listing all projects.
sub list_projects_url {
    my ($self) = @_;
    return Codestriker::Http::Method::ListProjectsMethod->new($self->{query})->url();
}

# Construct a URL for creating a project.
sub create_project_url {
    my ($self) = @_;
    return Codestriker::Http::Method::CreateProjectMethod->new($self->{query})->url();
}

# Create the URL for viewing comments.
sub view_comments_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::ViewTopicCommentsMethod->new($self->{query})->url(%args);
}

# Create the URL for updating comments.
sub update_comments_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::UpdateCommentMetricsMethod->new($self->{query})->url(%args);
}

# Create the URL for viewing the topic properties.
sub view_topic_properties_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::ViewTopicPropertiesMethod->new($self->{query})->url(%args);
}

# Create the URL for updating the topic properties.
sub update_topic_properties_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::UpdateTopicPropertiesMethod->new($self->{query})->url(%args);
}

# Create the URL for viewing the topic metrics.
sub view_topicinfo_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::ViewTopicMetricsMethod->new($self->{query})->url(%args);
}

# Create the URL for updating the topic metrics.
sub update_topicinfo_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::UpdateTopicMetricsMethod->new($self->{query})->url(%args);
}

# Create the URL for updating a number of topic states.
sub update_topic_states_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::UpdateTopicStateMethod->new($self->{query})->url(%args);
}

# Create the URL for adding new comments.
sub add_comment_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::AddCommentMethod->new($self->{query})->url(%args);
}

sub metric_report_url {
    my ($self) = @_;
    return Codestriker::Http::Method::ViewMetricsMethod->new($self->{query})->url();
}

sub metric_report_download_raw_data {
    my ($self) = @_;
    return Codestriker::Http::Method::DownloadMetricsMethod->new($self->{query})->url();
}

1;
