###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of topic search.

package Codestriker::Action::SubmitSearch;

use strict;

# If the input is valid, redirect the user to the appropriate topic view
#  screen.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $sauthor = $http_input->get('sauthor') || "";
    my $sreviewer = $http_input->get('sreviewer') || "";
    my $scc = $http_input->get('scc') || "";
    my $sbugid = $http_input->get('sbugid') || "";
    my $stext = $http_input->get('stext') || "";
    
    # Process the text search checkboxes.
    my @text_group = $query->param('text_group');
    my $search_title = 0;
    my $search_description = 0;
    my $search_comments = 0;
    my $search_body = 0;
    my $search_filename = 0;
    if ($stext ne "") {
	for (my $i = 0; $i <= $#text_group; $i++) {
	    if ($text_group[$i] eq "title") {
		$search_title = 1;
	    } elsif ($text_group[$i] eq "description") {
		$search_description = 1;
	    } elsif ($text_group[$i] eq "comment") {
		$search_comments = 1;
	    } elsif ($text_group[$i] eq "body") {
		$search_body = 1;
	    } elsif ($text_group[$i] eq "filename") {
		$search_filename = 1;
	    }
	}
    }

    # Process the state multi-popup.
    my @state_group = $query->param('state_group');
    my @stateids;
    for (my $i = 0; $i <= $#state_group; $i++) {
	if ($state_group[$i] eq "Any") {
	    # No need to encode anything in the URL.
	    @stateids = ();
	    last;
	}
	for (my $j = 0; $j <= $#Codestriker::topic_states; $j++) {
	    if ($state_group[$i] eq $Codestriker::topic_states[$j]) {
		push @stateids, $j;
		    last;
	    }
	}
    }

    # Process the project multi-popup.
    my @project_group = $query->param('project_group');
    my @projectids;
    for (my $i = 0; $i <= $#project_group; $i++) {
	if ($project_group[$i] == -1) {
	    # No need to encode anything in the URL.
	    @projectids = ();
	    last;
	}
	push @projectids, $project_group[$i];
    }

    # Redirect the user to the list topics page.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);
    my $redirect_url =
	$url_builder->list_topics_url($sauthor, $sreviewer, $scc, $sbugid,
				      $stext, $search_title,
				      $search_description, $search_comments,
				      $search_body, $search_filename,
				      \@stateids, \@projectids);

    print $query->redirect(-URI=>$redirect_url);
}

1;
