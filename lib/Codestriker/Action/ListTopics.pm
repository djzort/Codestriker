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

# find out which format to display the list in
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $format = $http_input->get('format');

    if (defined $format && $format eq "xml") {
	process_xml($type, $http_input, $http_response);
    } else {
	process_default($type, $http_input, $http_response);
    }
}


# If the input is valid, list the appropriate topics.
sub process_default($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check if this action is allowed.
    if ($Codestriker::allow_searchlist == 0) {
	$http_response->error("This function has been disabled");
    }

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    my $mode = $http_input->get('mode');
    my $feedback = $http_input->get('feedback');
    my $projectid = $http_input->get('projectid');

    my ( $sauthor, $sreviewer, $scc, $sbugid,
         $sstate, $sproject, $stext,
         $stitle, $sdescription,
	 $scomments, $sbody, $sfilename,
         $sort_order) = get_topic_list_query_params($http_input);

    # Query the model for the specified data.
    my @topics = Codestriker::Model::Topic->query($sauthor, $sreviewer, $scc, $sbugid,
				     $sstate, $sproject, $stext,
				     $stitle, $sdescription,
				     $scomments, $sbody, $sfilename,
                                     $sort_order);

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
				    topicsort=>join(',',@$sort_order),
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

    # Collect the comment metric counts that they want to show on the main page.
    my @comment_metric_names;
    foreach my $comment_state_metric (@{$Codestriker::comment_state_metrics}) {
        if (exists($comment_state_metric->{show_on_mainpage})) {
            foreach my $value (@{$comment_state_metric->{show_on_mainpage}}) {
                push @comment_metric_names,
		     { name => $comment_state_metric->{name},
		       value => $value };
            }
        }
    }

    $vars->{'commentmetrics'} = \@comment_metric_names;

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

    $vars->{'list_sort_url_rss'} = 
	$url_builder->list_topics_url_rss($sauthor, $sreviewer, $scc, $sbugid,
				      $stext, $stitle,
				      $sdescription, $scomments,
				      $sbody, $sfilename,
				      [ split ',', $sstate] , \@project_ids);

    # The list of topics in the template toolkit.
    my @template_topics;

    # For each topic, collect all the reviewers, CC, and bugs, and display it
    # as a row in the table.  Each bug should be linked appropriately. 
    foreach my $topic (@topics) {

        # do the easy stuff first, 1 to 1 mapping into the template.
   
	my $template_topic = {};

	$template_topic->{'view_topic_url'} = 
	    $url_builder->view_url($topic->{topicid}, -1, $mode,
				   $Codestriker::default_topic_br_mode);
        
	$template_topic->{'description'} = $topic->{description};

	$template_topic->{'created'} =
	    Codestriker->format_short_timestamp($topic->{creation_ts});

	$template_topic->{'id'}      = $topic->{topicid};
	$template_topic->{'title'}   = $topic->{title};

	$template_topic->{'version'} = $topic->{version};

	$template_topic->{'state'}   = $Codestriker::topic_states[$topic->{topic_state_id}];

	# Only include the username part of the email address to save space.
	my $accum_author = $topic->{author};
        $accum_author =~ s/\@.*$//o;
	$template_topic->{'author'} = $accum_author;

        # cc
	my $cc = $topic->{cc};
        $cc =~ s/\@.*$//o;
	$template_topic->{'cc'}     = $cc;

        # bug ids
	my @accum_bugs = split /, /, $topic->{bug_ids};
	for (my $index = 0; $index < scalar(@accum_bugs); ++$index) {
	    # Allow for no direct web link to a bug.
	    if (defined $Codestriker::bugtracker &&
                $Codestriker::bugtracker ne '') {
	        $accum_bugs[$index] =
		    $query->a({href=>"$Codestriker::bugtracker$accum_bugs[$index]"},
      	                      $accum_bugs[$index]);
	    }
	}
	$template_topic->{'bugids'} = join ', ', @accum_bugs;

        # do the reviewers
        my @reviewers_vistited = 
            $topic->get_metrics()->get_list_of_actual_topic_participants();

	my @reviewers = split /, /, $topic->{reviewers};
	for ( my $index = 0; $index < scalar(@reviewers); ++$index) {

            my $reviewer = $reviewers[$index];

            my $is_visted = 0;
            foreach my $visted (@reviewers_vistited) {
                if ($visted eq $reviewer) {
                    $is_visted = 1;
                    last;
                }
	    }

	    # Output the accumulated information into the row.  Only
	    # include the username part of an email address for now to
	    # save some space.  This should be made a dynamic option
	    # in the future.
            $reviewer =~ s/\@.*$//o;

            if ( $is_visted == 0) {
                $reviewer = "(" . $reviewer . ")";
            }           
                    
            $reviewers[$index] = $reviewer;      
                    }

	$template_topic->{'reviewer'} = join(", ",@reviewers);

        my @main_page_comment_metrics = ();
        foreach my $comment_state_metric (@{$Codestriker::comment_state_metrics}) {
        
            if ( exists($comment_state_metric->{show_on_mainpage})) {
                foreach my $value (@{$comment_state_metric->{show_on_mainpage}}) {

                    my $count = $topic->get_comment_metric_count($comment_state_metric->{name},$value);

                    my $template_comment_metric = 
                    {
                        name  => $comment_state_metric->{name},
                        value => $value,
                        count => $count
                    };

                    push @main_page_comment_metrics,$template_comment_metric;
		}
	    }
	}

        $template_topic->{'commentmetrics'} = \@main_page_comment_metrics;

	push @template_topics, $template_topic;
    }

    $vars->{'topics'} = \@template_topics;
    $vars->{'states'} = \@Codestriker::topic_states;

    $vars->{'list_projects_url'} = $url_builder->list_projects_url();
    $vars->{'view_metrics_url'} = $url_builder->metric_report_url();

    my $template = Codestriker::Http::Template->new("listtopics");
    $template->process($vars);

    $http_response->generate_footer();
}


# If the input is valid, display the topic.
sub process_xml($$$) {
    my ($self, $http_input, $http_response) = @_;

    my $sbugid = $http_input->get('sbugid') || "";
    my $sauthor = $http_input->get('sauthor') || "";
    my $sreviewer = $http_input->get('sreviewer') || "";
    my $scc = $http_input->get('scc') || "";
    my $stext = $http_input->get('stext') || "";

    my @sort_order;
    my @topics = Codestriker::Model::Topic->query($sauthor,
    						  $sreviewer,
    						  $scc,
    						  $sbugid,
						  "", "",
						  $stext,
						  "", "", "", "", "",
						  \@sort_order );

    my $var;
    $var->{ alltopics } = \@topics;

    # Fire the template for generating the view topic screen.
    my $template = Codestriker::Http::Template->new("listtopics", "xml");
    $template->process($var);
}


# Process the input and return the parts that will feed into the topic
# list query. Returns in the same order that the topic query function
# takes them.
sub get_topic_list_query_params {
    my ($http_input) = @_;

    # Check that the appropriate fields have been filled in.
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
    my @sort_order = get_topic_sort_order($http_input);

    return ( $sauthor, $sreviewer, $scc, $sbugid,
				     $sstate, $sproject, $stext,
				     $stitle, $sdescription,
				     $scomments, $sbody, $sfilename,
                                     \@sort_order);
}

# Process the topic_sort_change input request (if any), and the current sort 
# cookie (topicsort), and returns a list that defines the topic sort order
# that should be used for this request. The function will ensure that 
# column types are not repeated, and will sort in the opposite direction
# if the user clicks on the same column twice.
sub get_topic_sort_order {
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

1;
