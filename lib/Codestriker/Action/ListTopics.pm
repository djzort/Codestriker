###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying a list of topics.

package Codestriker::Action::ListTopics;

use strict;
use Codestriker::Http::Template;
use Codestriker::Model::Topic;

# If the input is valid, list the appropriate topics.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check if this action is allowed.
    if ($Codestriker::allow_searchlist == 0) {
	$http_response->error("This function has been disabled");
    }

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Check that the appropriate fields have been filled in.
    my $mode = $http_input->get('mode');
    my $sauthor = $http_input->get('sauthor') || "";
    my $sreviewer = $http_input->get('sreviewer') || "";
    my $scc = $http_input->get('scc') || "";
    my $sbugid = $http_input->get('sbugid') || "";
    my $stext = $http_input->get('stext') || "";
    my $sstate = $http_input->get('sstate');
    my $sproject = $http_input->get('sproject');
    my $stitle = $http_input->get('stitle') || 0;
    my $sdescription = $http_input->get('sdescription') || 0;
    my $scomments = $http_input->get('scomments') || 0;
    my $sbody = $http_input->get('sbody') || 0;
    my $sfilename = $http_input->get('sfilename') || 0;
    my $feedback = $http_input->get('feedback');
    my $projectid = $http_input->get('projectid');

    # If $sproject has been set to -1, then retrieve the value of the projectid
    # from the cookie as the project search value.  This is done to facilate
    # integration with other systems, which jump straight to this URL, and
    # set the cookie explicitly.
    if ($sproject eq "-1") {
	$sproject = (defined $projectid) ? $projectid : "";
    }
    
    # Only show open topics if codestriker.pl was run without parameters.
    if (defined($http_input->{query}->param) == 0 || !defined($sstate)) {
    	$sstate = 0; 
    }

    # handle the sort order of the topics.
    my @sort_order = _get_topic_sort_order($http_input);

    # Query the model for the specified data.
    my (@state_group_ref, @text_group_ref);
    my (@id, @title, @author, @ts, @state, @bugid, @email, @type, @version);

    Codestriker::Model::Topic->query($sauthor, $sreviewer, $scc, $sbugid,
				     $sstate, $sproject, $stext,
				     $stitle, $sdescription,
				     $scomments, $sbody, $sfilename,
                                     \@sort_order,
				     \@id, \@title,
				     \@author, \@ts, \@state, \@bugid,
				     \@email, \@type, \@version);

    # Display the data, with each topic title linked to the view topic screen.
    # If only a single project id is being searched over, set that id in the
    # cookie.
    my @project_ids = ();
    if ($sproject ne "") {
	@project_ids = split ',', $sproject;
    }
    my $projectid_cookie = ($#project_ids == 0) ? $project_ids[0] : "";
    $http_response->generate_header(topic_title=>"Topic List", 
				    projectid=>$projectid_cookie, 
                                    topicsort=>join(',',@sort_order),
                                    reload=>0, cache=>0);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'feedback'} = $feedback;

    # Store the search parameters, which become hidden fields.
    $vars->{'sauthor'} = $sauthor;
    $vars->{'sreviewer'} = $sreviewer;
    $vars->{'scc'} = $scc;
    $vars->{'sbugid'} = $sbugid;
    $vars->{'stext'} = $stext;
    $vars->{'sstate'} = $sstate;
    $vars->{'stitle'} = $stitle;
    $vars->{'sdescription'} = $sdescription;
    $vars->{'scomments'} = $scomments;
    $vars->{'sbody'} = $sbody;
    $vars->{'sfilename'} = $sfilename;

    # The url generated here includes all of the search parameters, so
    # that the current list of topics the user it viewing does not
    # revert back to the default open topic list.  The search is
    # applied each time they change the sort order.
    $vars->{'list_sort_url'} = 
	$url_builder->list_topics_url($sauthor, $sreviewer, $scc, $sbugid,
				      $stext, $stitle,
				      $sdescription, $scomments,
				      $sbody, $sfilename,
				      [ split ',', $sstate] , \@project_ids);

    # The list of topics.
    my @topics;

    # For each topic, collect all the reviewers, CC, and bugs, and display it
    # as a row in the table.  Each bug should be linked appropriately.
    for (my $index = 0, my $row = 0; $index <= $#id; $row++) {
	my @accum_bugs = ();
	my @accum_reviewers = ();
	my @accum_cc = ();
	my $accum_id = $id[$index];
	my $accum_version = $version[$index];
	my $accum_title = $title[$index];
	my $accum_author = $author[$index];
	my $accum_ts = Codestriker->format_short_timestamp($ts[$index]);
	my $accum_state = $Codestriker::topic_states[$state[$index]];

	# Accumulate the bug ids, reviewers and cc here for the same topic.
	# Note these will be only a few elements long, if that.
	for (; $index <= $#id && $accum_id == $id[$index]; $index++) {
	    if (defined $bugid[$index]) {
		_insert_nonduplicate(\@accum_bugs, $bugid[$index]);
	    }
	    if (defined $email[$index]) {
		if ($type[$index] == $Codestriker::PARTICIPANT_REVIEWER) {
		    _insert_nonduplicate(\@accum_reviewers, $email[$index]);
		} else {
		    _insert_nonduplicate(\@accum_cc, $email[$index]);
		}
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
	my $cc_text = ($#accum_cc >= 0) ? (join ', ', @accum_cc) : "";

	for (my $i = 0; $i <= $#accum_bugs; $i++) {
	    $accum_bugs[$i] =
		$query->a({href=>"$Codestriker::bugtracker$accum_bugs[$i]"},
			  $accum_bugs[$i]);
	}
	my $bugid_text = join ', ', @accum_bugs;

	# Add this row to the list of topics.
	my $topic = {};
	$topic->{'view_topic_url'} =
	    $url_builder->view_url($accum_id, -1, $mode,
				   $Codestriker::default_topic_br_mode);
	$topic->{'id'} = $accum_id;
	$topic->{'title'} = $accum_title;
	$topic->{'author'} = $accum_author;
	$topic->{'reviewer'} = $reviewer_text;
	$topic->{'cc'} = $cc_text;
	$topic->{'created'} = $accum_ts;
	$topic->{'bugids'} = $bugid_text;
	$topic->{'state'} = $accum_state;
	$topic->{'version'} = $accum_version;
	push @topics, $topic;
    }
    $vars->{'topics'} = \@topics;
    $vars->{'states'} = \@Codestriker::topic_states;

    $vars->{'list_projects_url'} = $url_builder->list_projects_url();

    $vars->{'view_metrics_url'} = $url_builder->metric_report_url();

    # Record the search parameters.

    my $template = Codestriker::Http::Template->new("listtopics");
    $template->process($vars);

    $http_response->generate_footer();
}

# Process the topic_sort_change input request (if any), and the current sort 
# cookie (topicsort), and returns a list that defines the topic sort order
# that should be used for this request. The function will ensure that 
# column types are not repeated, and will sort in the opposite direction
# if the user clicks on the same column twice.
sub _get_topic_sort_order {
    my ($http_input) = @_;

    my $topic_sort_change = $http_input->get('topic_sort_change');
    my $topicsort = $http_input->get('topicsort');

    my @sort_order = split(/,/,$topicsort); # this is always from the cookie.

    if ($topic_sort_change ne "") {
        if (scalar(@sort_order) > 0) {

            # If the user clicked on the same column twice in a row, reverse
            # the direction of the sort.
            
            $sort_order[0] =~ s/\+$topic_sort_change/\-$topic_sort_change/ or
            $sort_order[0] =~ s/\-$topic_sort_change/\+$topic_sort_change/ or        
            unshift @sort_order, "+" . $topic_sort_change;
        }
        else {
            unshift @sort_order, "+" . $topic_sort_change;
        }

        # look for duplicate sort keys, and remove
        my %sort_hash;

        for ( my $index = 0; 
              $index < scalar( @sort_order); 
              # Incremented in the if...
              ) {

            # chew off the leading +-
            my $current = $sort_order[$index];

            if ($current =~ s/^[\+\-]//) {
                if (exists $sort_hash{$current}) {
                    # remove from the list.
                    splice @sort_order, $index,1;
                }
                else {
                    # have not seem this before, keep it, and look at the next
                    # string.
                    ++$index;                
                }

                $sort_hash{$current} = 1;
            } 
        }
    }


    # Pull out any elements that are not valid (from a bad cookie or from a bad
    # input.

    for (my $index = 0; $index < scalar(@sort_order) ; ++$index) {

        if ($sort_order[$index] ne "+title" && $sort_order[$index] ne "-title" &&
            $sort_order[$index] ne "+author" && $sort_order[$index] ne "-author" &&
            $sort_order[$index] ne "+created" && $sort_order[$index] ne "-created" &&
            $sort_order[$index] ne "+state" && $sort_order[$index] ne "-state") {
            
            splice @sort_order,$index,1;
            --$index;
        }
    }

    return @sort_order;
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
