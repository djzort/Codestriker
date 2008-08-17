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

# Generate a URL for this method.
sub url() {
	my ($self, %args) = @_;
	
    confess "Parameter topicid missing" unless defined $args{topicid};
   	confess "Parameter projectid missing" unless defined $args{projectid};

    if ($self->{cgi_style}) {
	    return $self->{url_prefix} . "?action=view&topic=$args{topicid}" .
		       (defined $args{updated} ? "&updated=$args{updated}" : "") .
			   (defined $args{tabwidth} ? "&tabwidth=$args{tabwidth}" : "") .
			   (defined $args{mode} ? "&mode=$args{mode}" : "") .
			   (defined $args{fview} ? "&fview=$args{fview}" : "") .
			   (defined $args{filenumber} ? "#" . "$args{filenumber}|$args{line}|$args{new}" : "");
    } else {
    	return $self->{url_prefix} . "/project/$args{projectid}/topic/$args{topicid}/text" .
    	       (defined $args{fview} ? "/filenumber/$args{filenumber}" : "") .
    	       (defined $args{mode} ? "/mode/$args{mode}" : "") .
			   (defined $args{filenumber} ? "#" . "$args{filenumber}|$args{line}|$args{new}" : "");
    }    
}

sub extract_parameters {
	my ($self, $http_input) = @_;
	
	my $action = $http_input->{query}->param('action'); 
    my $path_info = $http_input->{query}->path_info();
    if ($self->{cgi_style} && defined $action && $action eq "view") {  
		$http_input->extract_cgi_parameters();
		return 1;
	} elsif ($path_info =~ m{^$self->{url_prefix}/project/\d+/topic/\d+/text}) {
	    $self->_extract_nice_parameters($http_input,
	                                    project => 'projectid', topic => 'topicid',
	                                    filenumber => 'fview', mode => 'mode');
		return 1;
	} else {
		return 0;
	}
}

sub execute {
	my ($self, $http_input, $http_output) = @_;
	
	Codestriker::Action::ViewTopic->process($http_input, $http_output);
}

1;
