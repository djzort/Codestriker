###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying a list of topics.

package Codestriker::Action::ListTopics;

use strict;

# If the input is valid, create the appropriate topic into the database.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $sauthor = $http_input->get('sauthor') || "";
    my $sreviewer = $http_input->get('sreviewer') || "";
    my $scc = $http_input->get('scc') || "";
    my $sbugid = $http_input->get('sbugid') || "";
    my $stext = $http_input->get('stext') || "";
    my $sstate = $http_input->get('sstate');
    my $stitle = $http_input->get('stitle') || 0;
    my $sdescription = $http_input->get('sdescription') || 0;
    my $scomments = $http_input->get('scomments') || 0;
    my $sbody = $http_input->get('sbody') || 0;
    
    # Perform some error checking here on the parameters.

    # Query the model for the specified data.
    my (@state_group_ref, @text_group_ref);
    my (@id, @title, @author, @ts, @state, @bugid, @email, @type);
    Codestriker::Model::Topic->query($sauthor, $sreviewer, $scc, $sbugid,
				     $sstate, $stext, $stitle, $sdescription,
				     $scomments, $sbody, \@id, \@title,
				     \@author, \@ts, \@state, \@bugid,
				     \@email, \@type);

    # Display the data, with each topic title linked to the view topic screen.
    $http_response->generate_header("", "Topic list", "", "", "", "", "", "",
				    0, 0);

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Display the "Create a new topic" and "Search" links.
    my $create_topic_url = $url_builder->create_topic_url();
    my $search_url = $url_builder->search_url();
    print $query->a({href=>$create_topic_url}, "Create new topic") . " | ";
    print $query->a({href=>$search_url}, "Search") . "\n";
    print $query->p;

    # Display the table header.
    print $query->h1("Topic list"), $query->p;
    print $query->start_table({-width=>'100%'});
    print $query->Tr({-class=>'tlh'},
		     $query->th("Title"), $query->th("Author"),
		     $query->th("Reviewer"), $query->th("Cc"),
		     $query->th("Created"), $query->th("Bug IDs"),
		     $query->th("State"));

    # For each topic, collect all the reviewers, CC, and bugs, and display it
    # as a row in the table.  Each bug should be linked appropriately.
    for (my $index = 0, my $row = 0; $index <= $#id; $row++) {
	my @accum_bugs = ();
	my @accum_reviewers = ();
	my @accum_cc = ();
	my $accum_id = $id[$index];
	my $accum_title = CGI::escapeHTML($title[$index]);
	my $accum_author = $author[$index];
	my $accum_ts = Codestriker->format_short_timestamp($ts[$index]);
	my $accum_state = $Codestriker::topic_states[$state[$index]];

	# Accumulate the bug ids, reviewers and cc here for the same topic.
	# Note these will be only a few elements long, if that.
	for (; $index <= $#id && $accum_id == $id[$index]; $index++) {
	    if (defined $bugid[$index]) {
		_insert_nonduplicate(\@accum_bugs, $bugid[$index]);
	    }
	    if (defined $email[$index] &&
		$type[$index] == $Codestriker::PARTICIPANT_REVIEWER) {
		_insert_nonduplicate(\@accum_reviewers, $email[$index]);
	    } else {
		_insert_nonduplicate(\@accum_cc, $email[$index]);
	    }
	}

	# Output the accumulated information into the row.  Only include the
	# username part of an email address for now to save some space.  This
	# should be made a dynamic option in the future.
	$accum_author =~ s/\@.*$//o;
	for (my $i = 0; $i <= $#accum_reviewers; $i++) {
	    $accum_reviewers[$i] =~ s/\@.*$//o;
	}
	for (my $i = 0; $i <= $#accum_cc; $i++) {
	    $accum_cc[$i] =~ s/\@.*$//o;
	}
	
	my $reviewer_text = join ', ', @accum_reviewers;
	$reviewer_text = "&nbsp;" if $reviewer_text eq "";
	my $cc_text = join ', ', @accum_cc;
	$cc_text = "&nbsp;" if $cc_text eq "";
	for (my $i = 0; $i <= $#accum_bugs; $i++) {
	    $accum_bugs[$i] =
		$query->a({href=>"$Codestriker::bugtracker$accum_bugs[$i]"},
			  $accum_bugs[$i]);
	}
	my $bugid_text = join ', ', @accum_bugs;
	$bugid_text = "&nbsp;" if $bugid_text eq "";

	# Alternate the row colours.
	my $view_topic_url = $url_builder->view_url($accum_id, -1, "");
	my $class = $row % 2 == 0 ? 'tl1' : 'tl2';
	print $query->Tr({-class=>$class},
			 $query->td($query->a({href=>$view_topic_url},
					      $accum_title)),
			 $query->td($accum_author),
			 $query->td($reviewer_text),
			 $query->td($cc_text),
			 $query->td($accum_ts),
			 $query->td($bugid_text),
			 $query->td($accum_state)) . "\n";
    }

    print $query->end_table();
}

# Append an element into an array if it doesn't exist already.  Note this is
# only called for arrays of very small sizes (ie typically 1-2 elements).
sub _insert_nonduplicate(\@$) {
    my ($array_ref, $value) = @_;
    my @array = @$array_ref;
    my $i;
    for ($i = 0; $i <= $#array; $i++) {
	last if ($array[$i] eq $value);
    }
    push @$array_ref, $value if ($i > $#array);
}
			 
1;
