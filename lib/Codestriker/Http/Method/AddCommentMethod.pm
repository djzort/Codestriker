###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for adding a comment to a topic.

package Codestriker::Http::Method::AddCommentMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::AddCommentMethod::ISA = ("Codestriker::Http::Method");

# Generate a URL for this method.
sub url() {
	my ($self, %args) = @_;
	
    die "Parameter topicid missing" unless defined $args{topicid};
   	die "Parameter projectid missing" unless defined $args{projectid};

    if ($self->{cgi_style}) {
	    return $self->{url_prefix} . "?action=edit&fn=$args{filenumber}&line=$args{line}&new=$args{new}&topic=$args{topicid}" .
		(defined $args{anchor} ? "&a=$args{anchor}" : "") .
		(defined $args{context} ? "&context=$args{context}" : "");
    } else {
    	return $self->{url_prefix} . "/project/$args{projectid}/topic/$args{topicid}/comment/" .
    	       "$args{filenumber}|$args{line}|$args{new}/add" .
		       (defined $args{anchor} ? "/anchor/$args{anchor}" : "") .
		       (defined $args{context} ? "/context/$args{context}" : "");
    }
}

sub extract_parameters {
	my ($self, $http_input) = @_;
	
	my $action = $http_input->{query}->param('action'); 
    my $path_info = $http_input->{query}->path_info();
    if ($self->{cgi_style} && defined $action && $action eq "edit") {  
		$http_input->extract_cgi_parameters();
		return 1;
	} elsif ($path_info =~ m{^$self->{url_prefix}/project/\d+/topic/\d+/comment/(\d+)\|(\d+)\|(\d+)/add}) {
		$http_input->{fn} = $1;
		$http_input->{line} = $2;
		$http_input->{new} = $3;
	    $self->_extract_nice_parameters($http_input,
	                                    project => 'projectid', topic => 'topicid',
	                                    anchor => 'anchor', context => 'context');
		return 1;
	} else {
		return 0;
	}
}

sub execute {
	my ($self, $http_input, $http_output) = @_;
	
	Codestriker::Action::EditComment->process($http_input, $http_output);
}

1;
