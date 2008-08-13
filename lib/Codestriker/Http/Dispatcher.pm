###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Module for dispatching a URL to the appropriate Action class.

package Codestriker::Http::Dispatcher;

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
use Codestriker::Http::Method::EditProjectMethod;
use Codestriker::Http::Method::ListProjectsMethod;
use Codestriker::Http::Method::SearchTopicsMethod;
use Codestriker::Http::Method::StaticResourcesMethod;
use Codestriker::Http::Method::ViewMetricsMethod;

# Initialise all of the methods that are known to the system.
# TODO: add configuration to the parameter.
sub new {
	my ($type, $query) = @_;
	
    my $self = {};
    $self->{list_topics_method} =
        Codestriker::Http::Method::ListTopicsMethod->new($query); 
    $self->{create_topic_method} =
        Codestriker::Http::Method::CreateTopicMethod->new($query); 

	my @methods = ();
	push @methods, Codestriker::Http::Method::ViewTopicTextMethod->new($query);
	push @methods, Codestriker::Http::Method::ViewTopicCommentsMethod->new($query);
	push @methods, Codestriker::Http::Method::ViewTopicFileMethod->new($query);
	push @methods, Codestriker::Http::Method::ViewTopicMetricsMethod->new($query);
	push @methods, Codestriker::Http::Method::ViewTopicPropertiesMethod->new($query);
	push @methods, $self->{list_topics_method};
	push @methods, Codestriker::Http::Method::AddCommentMethod->new($query);
	push @methods, Codestriker::Http::Method::AddTopicMethod->new($query);
	push @methods, Codestriker::Http::Method::CreateProjectMethod->new($query);
	push @methods, $self->{create_topic_method};
	push @methods, Codestriker::Http::Method::DownloadMetricsMethod->new($query);
	push @methods, Codestriker::Http::Method::EditProjectMethod->new($query);
	push @methods, Codestriker::Http::Method::ListProjectsMethod->new($query);
	push @methods, Codestriker::Http::Method::SearchTopicsMethod->new($query);
	push @methods, Codestriker::Http::Method::StaticResourcesMethod->new($query);
	push @methods, Codestriker::Http::Method::ViewMetricsMethod->new($query);

	$self->{methods} = \@methods;
    return bless $self, $type;
}

# Determine which method can satisfy the input request and dispatch it
# to the appropriate action.
sub dispatch {
	my ($self, $http_input, $http_output) = @_;
	
	foreach my $method ( @{$self->{methods}} ) {
		if ($method->extract_parameters($http_input)) {
			$method->execute($http_input, $http_output);
			return;
		}
	}
	
	# If we have reached here, execute the default method.
	if ($Codestriker::allow_searchlist) {
		$self->{list_topics_method}->execute($http_input, $http_output);
    } else {
		$self->{create_topic_method}->execute($http_input, $http_output);
	}
}

1;