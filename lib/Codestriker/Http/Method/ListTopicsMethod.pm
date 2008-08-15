###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for listing topics.

package Codestriker::Http::Method::ListTopicsMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::ListTopicsMethod::ISA =
    ("Codestriker::Http::Method");

# Generate a URL for this method.
sub url() {
	my ($self, %args) = @_;
	
    my $sstate = defined $args{sstate} ? CGI::escape(join ',', @{$args{sstate}}) : "";
    my $sproject = defined $args{sproject} ? CGI::escape(join ',', @{$args{sproject}}) : "";
    my $action = defined $args{rss} && $args{rss} ? "list_topics_rss" : "list_topics";
    
    if ($self->{cgi_style}) {
        return $self->{url_prefix} . "?action=$action" .
	           (defined $args{sauthor} && $args{sauthor} ne "" ? "&sauthor=" . CGI::escape($args{sauthor}) : "") .
	           (defined $args{sreviewer} && $args{sreviewer} ne "" ? "&sreviewer=" . CGI::escape($args{sreviewer}) : "") .
	           (defined $args{scc} && $args{scc} ne "" ? "&scc=" . CGI::escape($args{scc}) : "") .
	           (defined $args{sbugid} && $args{sbugid} ne "" ? "&sbugid=" . CGI::escape($args{sbugid}) : "") .
	           (defined $args{stext} && $args{stext} ne "" ? "&stext=" . CGI::escape($args{stext}) : "") .
	           (defined $args{stitle} && $args{stitle} ne "" ? "&stitle=" . CGI::escape($args{stitle}) : "") .
	           (defined $args{sdescription} && $args{sdescription} ne "" ? "&sdescription=" . CGI::escape($args{sdescription}) : "") .
	           (defined $args{scomments} && $args{scomments} ne "" ? "&scomments=" . CGI::escape($args{scomments}) : "") .
	           (defined $args{sbody} && $args{sbody} ne "" ? "&sbody=" . CGI::escape($args{sbody}) : "") .
	           (defined $args{sfilename} && $args{sfilename} ne "" ? "&sfilename=" . CGI::escape($args{sfilename}) : "") .
	           (defined $args{content} && $args{content} ne "" ? "&content=" . CGI::escape($args{content}) : "") .
	           ($sstate ne "" ? "&sstate=$sstate" : "") .
	           ($sproject ne "" ? "&sproject=$sproject" : "");
    } else {
		return $self->{url_prefix} .
		       ($action eq "list_topics_rss" ? "/feed" : "") . "/topics/list" .
	           (defined $args{sauthor} && $args{sauthor} ne "" ? "/author/" . CGI::escape($args{sauthor}) : "") .
	           (defined $args{sreviewer} && $args{sreviewer} ne "" ? "/reviewer/" . CGI::escape($args{sreviewer}) : "") .
	           (defined $args{scc} && $args{scc} ne "" ? "/cc/" . CGI::escape($args{scc}) : "") .
	           (defined $args{sbugid} && $args{sbugid} ne "" ? "/bugid/" . CGI::escape($args{sbugid}) : "") .
	           (defined $args{stext} && $args{stext} ne "" ? "/text/" . CGI::escape($args{stext}) : "") .
	           (defined $args{stitle} && $args{stitle} ne "" ? "/title/" . CGI::escape($args{stitle}) : "") .
	           (defined $args{sdescription} && $args{sdescription} ne "" ? "/description/" . CGI::escape($args{sdescription}) : "") .
	           (defined $args{scomments} && $args{scomments} ne "" ? "/comment/" . CGI::escape($args{scomments}) : "") .
	           (defined $args{sbody} && $args{sbody} ne "" ? "/body/" . CGI::escape($args{sbody}) : "") .
	           (defined $args{sfilename} && $args{sfilename} ne "" ? "/filename/" . CGI::escape($args{sfilename}) : "") .
	           (defined $args{content} && $args{content} ne "" ? "/content/" . CGI::escape($args{content}) : "") .
	           ($sstate ne "" ? "/state/$sstate" : "") .
	           ($sproject ne "" ? "/project/$sproject" : "");
    }
}

sub extract_parameters {
	my ($self, $http_input) = @_;
	
	my $action = $http_input->{query}->param('action'); 
    my $path_info = $http_input->{query}->path_info();
    if ($self->{cgi_style} && defined $action && 
        ($action eq "list_topics" || $action eq "list_topics_rss")) { 
		$http_input->extract_cgi_parameters();
		return 1;
	} elsif ($path_info =~ m{^$self->{url_prefix}/feed/topics/list} ||
	         $path_info =~ m{^$self->{url_prefix}/topics/list}) {
	    $self->_extract_nice_parameters($http_input,
	                                    author => 'sauthor', reviewer => 'sreviewer',
	                                    cc => 'scc', bugid => 'sbugid', text => 'stext',
	                                    title => 'stitle', description => 'sdescription',
	                                    comment => 'scomments', body => 'sbody',
	                                    filename => 'sfilename', content => 'content',
	                                    state => 'sstate', project => 'sproject');
		return 1;
	} else {
		return 0;
	}
}

sub execute {
	my ($self, $http_input, $http_output) = @_;
	
	Codestriker::Action::ListTopics->process($http_input, $http_output);
}

1;
