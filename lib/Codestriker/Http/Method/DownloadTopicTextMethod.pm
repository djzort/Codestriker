###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for downloading the topic text.

package Codestriker::Http::Method::DownloadTopicTextMethod;

use strict;
use Carp;
use Codestriker::Http::Method;

@Codestriker::Http::Method::DownloadTopicTextMethod::ISA =
    ("Codestriker::Http::Method");

# Generate a URL for this method.
sub url() {
	my ($self, %args) = @_;
	
    confess "Parameter topicid missing" unless defined $args{topicid};

    if ($self->{cgi_style}) {
	    return $self->{url_prefix} . "?action=download&topic=$args{topicid}";
    } else {
   	    confess "Parameter projectid missing" unless defined $args{projectid};
    	return $self->{url_prefix} . "/project/$args{projectid}/topic/$args{topicid}/download";
    }    
}

sub extract_parameters {
	my ($self, $http_input) = @_;
	
	my $action = $http_input->{query}->param('action'); 
    my $path_info = $http_input->{query}->path_info();
    if ($self->{cgi_style} && defined $action && $action eq "download") {  
		$http_input->extract_cgi_parameters();
		return 1;
	} elsif ($path_info =~ m{^/project/\d+/topic/\d+/download}) {
	    $self->_extract_nice_parameters($http_input,
	                                    project => 'projectid', topic => 'topicid');
		return 1;
	} else {
		return 0;
	}
}

sub execute {
	my ($self, $http_input, $http_output) = @_;
	
	Codestriker::Action::DownloadTopic->process($http_input, $http_output);
}

1;
