###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for adding a topic to a project.

package Codestriker::Http::Method::AddTopicMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::AddTopicMethod::ISA = ("Codestriker::Http::Method");

# Generate a URL for this method.
sub url() {
    my ($self, %args) = @_;
	
   	die "Parameter projectid missing" unless defined $args{projectid};

    if ($self->{cgi_style}) {
        return $self->{url_prefix} . "?action=submit_new_topic";
    } else {
    	return $self->{url_prefix} . "/project/$args{projectid}/topics/add";
    }
}

sub extract_parameters {
	my ($self, $http_input) = @_;
	
	my $action = $http_input->{query}->param('action'); 
    my $path_info = $http_input->{query}->path_info();
    if ($self->{cgi_style} && defined $action && $action eq "submit_new_topic") {  
		$http_input->extract_cgi_parameters();
		return 1;
	} elsif ($path_info =~ m{^$self->{url_prefix}/project/\d+/topics/add}) {
	    $self->_extract_nice_parameters($http_input,
	                                    project => 'projectid');
		return 1;
	} else {
		return 0;
	}
}

sub execute {
	my ($self, $http_input, $http_output) = @_;
	
	Codestriker::Action::SubmitNewTopic->process($http_input, $http_output);
}

1;
