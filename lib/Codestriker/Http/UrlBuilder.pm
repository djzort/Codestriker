###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Collection of routines for building codestriker URLs.

# TODO, handle URL scheme such as:
# UrlBuilder needs to be smart and know how to handle the old and new scheme.
# Config variable could disable old scheme, then perhaps way to set security
# on location.

# Need a populate parameters method to set http_input hash.
# map new anchor -> a and filenumber -> fn.

# TODO: fix javascript eo method.
# 

# For eahc method, need object to generate_url(%args), and another that takes query object and sets
# parameters to $http_input.  These could be unit tested as well.  Object called Action.
# When processing input, each object could check query, and return false if can't handle it?
# For CGI case, can always handle it.  Could call it Method?  Might fit better into REST later.
# Process method could return associated action object?  better than large dispatch method currently
# present.
# process -> (%args, %http_input).

package Codestriker::Http::UrlBuilder;

use strict;
use CGI;

use Codestriker::Http::Method;
use Codestriker::Http::Method::ListTopics;

# Constructor for this class.
sub new {
    my ($type, $query, $cgi_style) = @_;
    my $self = {};

	$self->{query} = $query;
    $self->{cgi_style} = 1;
   	$self->{cgi_style} = $cgi_style if defined $cgi_style;

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
    }
    else {
	# Standard Codestriker deployment.
	$htmlurl = $self->{url_prefix};
	$htmlurl =~ s/codestriker\/codestriker\.pl/codestrikerhtml/;
    }
    $self->{htmldir} = $htmlurl;
    
    # Initialise all of the methods.
    $self->{list_topics_method} =
        Codestriker::Http::Method::ListTopics->new($self->{query}, $self->{url_prefix}, $self->{cgi_style});

    return bless $self, $type;
}

# Create the URL for viewing a topic.
sub view_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::ViewTopicTextMethod->new($query)->url(%args);
}

# Create the URL for downloading the topic text.
sub download_url {
    my ($self, %args) = @_;
    
    # TODO: handle this as parameter to view topic text.
    
    die "Parameter topicid missing" unless defined $args{topicid};
   	die "Parameter projectid missing" unless defined $args{projectid};

    if ($self->{cgi_style}) {
        return $self->{url_prefix} . "?action=download&topic=$args{topicid}";
    } else {
    	return $self->{url_prefix} . "/project/$args{projectid}/topic/$args{topicid}/download/text";
    }
}

# Create the URL for creating a topic.
sub create_topic_url {
    my ($self, $obsoletes) = @_;
    return Codestriker::Http::Method::CreateTopicMethod->new($query)->url($obsoletes);
}	    

# Create the URL for editing a topic.
sub edit_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::AddCommentMethod->new($query)->url(%args);
}

# Create the URL for viewing a new file.
sub view_file_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::ViewTopicFileMethod->new($query)->url(%args);
}

# Create the URL for the search page.
sub search_url {
    my ($self) = @_;
    return Codestriker::Http::Method::SearchTopicsMethod->new($query)->url(%args);
}

# Create the URL for the documentation page.
sub doc_url {
    my ($self) = @_;
    return Codestriker::Http::Method::StaticResourcesMethod->new($query)->url(%args);
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
    return Codestriker::Http::Method::ListTopicsMethod->new($query)->url(%args);
}


# Construct a URL for editing a specific project.
sub edit_project_url {
    my ($self, $projectid) = @_;
    return Codestriker::Http::Method::EditProjectMethod->new($query)->url($projectid);
}

# Construct a URL for listing all projects.
sub list_projects_url {
    my ($self) = @_;
    return Codestriker::Http::Method::ListProjectsMethod->new($query)->url();
}

# Construct a URL for creating a project.
sub create_project_url {
    my ($self) = @_;
    return Codestriker::Http::Method::CreateProjectMethod->new($query)->url();
}

# Create the URL for viewing comments.
sub view_comments_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::ViewTopicCommentsMethod->new($query)->url(%args);
}

# Create the URL for viewing the topic properties.
sub view_topic_properties_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::ViewTopicPropertiesMethod->new($query)->url(%args);
}

# Create the URL for viewing the topic metrics.
sub view_topicinfo_url {
    my ($self, %args) = @_;
    return Codestriker::Http::Method::ViewTopicMetricsMethod->new($query)->url(%args);
}

sub metric_report_url {
    my ($self) = @_;
    return Codestriker::Http::Method::ViewMetricsMethod->new($query)->url();
}

sub metric_report_download_raw_data {
    my ($self) = @_;
    return Codestriker::Http::Method::DownloadMetricsMethod->new($query)->url();
}

1;
