###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the viewing of a topic.

package Codestriker::Action::ViewTopicInfo;

use strict;

use Codestriker::Model::Topic;
use Codestriker::Model::Comment;
use Codestriker::Http::UrlBuilder;
use Codestriker::Repository::RepositoryFactory;
use HTML::Entities ();

# If the input is valid, display the topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    my $topicid = $http_input->get('topic');
    my $mode = $http_input->get('mode');
    my $tabwidth = $http_input->get('tabwidth');
    my $email = $http_input->get('email');
    my $feedback = $http_input->get('feedback');
    
    if (Codestriker::Model::Topic::exists($topicid) == 0) {
	# Topic no longer exists, most likely its been deleted.
	$http_response->error("Topic no longer exists.");
    }

    # Retrieve the appropriate topic details.           
    my $topic = Codestriker::Model::Topic->new($topicid);     

    # Retrieve line-by-line versions of the data and description.
    my @document_description = split /\n/, $topic->{description};

    # Retrieve the comment details for this topic.
    my @topic_comments = $topic->read_comments();

    $http_response->generate_header(topic=>$topic,
				    topic_title=>"Topic Properties: $topic->{title}", 
				    mode=>$mode, tabwidth=>$tabwidth,
				    reload=>0, cache=>1);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'feedback'} = $feedback;

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    Codestriker::Action::ViewTopic::ProcessTopicHeader($vars, $topic,
						       $url_builder);

    # Get the metrics configuration.  Its important to start from the
    # configuration so that the display matches the order of the config
    # file declaration.  Any unknown metric names/values will be appended.
    my @comment_metrics = ();
    my %comment_metric_tally = ();
    my $known_metrics;
    foreach my $metric_config (@{ $Codestriker::comment_state_metrics }) {
	my $metric_data = {};
	$metric_data->{name} = $metric_config->{name};
	$metric_data->{values} = $metric_config->{values};
	foreach my $value (@{ $metric_data->{values} }) {
	    $known_metrics->{$metric_config->{name}}->{$value} = 1;
	    $comment_metric_tally{$metric_config->{name}}->{$value} = 0;
	}
	$known_metrics->{$metric_config->{name}}->{'__array__'} =
	    $metric_config->{values};
	push @comment_metrics, $metric_data;
    }

    # Now tally the metric counts.  This code is complicated by having to
    # deal with old metric configurations that no longer mirror the current
    # active configuration.  The old values should still be reported.
    my $number_comments = 0;
    my $number_comment_threads = 0;
    my %processed_comment_thread = ();
    foreach my $comment (@topic_comments) {
	if (! exists $processed_comment_thread{$comment->{id}}) {
	    $processed_comment_thread{$comment->{id}} = 1;
	    $number_comment_threads++;

	    # Go through all the metric values stored in this comment thread.
	    foreach my $metric (keys %{ $comment->{metrics} }) {
		my $value = $comment->{metrics}->{$metric};
		$comment_metric_tally{$metric}->{$value}++;

		# If this is an old metric from an old config, make sure it
		# is included in the config for the final display.
		if (! defined $known_metrics->{$metric}) {
		    # Old metric name not in the current config.
		    my $metric_data = {};
		    $metric_data->{name} = $metric;
		    $metric_data->{values} = [ $value ];
		    $known_metrics->{$metric}->{$value} = 1;
		    $known_metrics->{$metric}->{'__array__'} =
			$metric_data->{values};
		    push @comment_metrics, $metric_data;
		} elsif (! defined $known_metrics->{$metric}->{$value}) {
		    # Known metric name, unknown value.
		    push @{ $known_metrics->{$metric}->{'__array__'} },
		         $value;
		    $known_metrics->{$metric}->{$value} = 1;
		}
	    }
	}
	$number_comments++;
    }

    $vars->{'comment_metrics'} = \@comment_metrics;
    $vars->{'comment_metric_tally'} = \%comment_metric_tally;
    $vars->{'number_comments'} = $number_comments;
    $vars->{'number_comment_threads'} = $number_comment_threads;

    my @projectids = ($topic->{project_id});

    $vars->{'view_topic_url'} =
	$url_builder->view_url($topicid, -1, $mode);

    $vars->{'view_topicinfo_url'} = $url_builder->view_topicinfo_url($topicid);
    $vars->{'view_comments_url'} = $url_builder->view_comments_url($topicid);
    $vars->{'list_projects_url'} = $url_builder->list_projects_url();

    # Display the "update" message if the topic state has been changed.
    $vars->{'updated'} = $http_input->get('updated');
    $vars->{'rc_ok'} = $Codestriker::OK;
    $vars->{'rc_stale_version'} = $Codestriker::STALE_VERSION;
    $vars->{'rc_invalid_topic'} = $Codestriker::INVALID_TOPIC;
    
    if ($topic->{bug_ids} ne "") {
	my @bugs = split ', ', $topic->{bug_ids};
	my $bug_string = "";
	for (my $i = 0; $i <= $#bugs; $i++) {
	    $bug_string .=
		$query->a({href=>"$Codestriker::bugtracker$bugs[$i]"},
			  $bugs[$i]);
	    $bug_string .= ', ' unless ($i == $#bugs);
	}
	$vars->{'bug_string'} = $bug_string;
    } else {
	$vars->{'bug_string'} = "";
    }

    $vars->{'document_reviewers'} = 
    	Codestriker->filter_email($topic->{reviewers});

    # Indicate what projects are available, and what the topic's project is.
    my @projects = Codestriker::Model::Project->list();
    $vars->{'projects'} = \@projects;
    $vars->{'topic_projectid'} = $topic->{project_id};

    $vars->{'number_of_lines'} = $topic->get_topic_size_in_lines();

    $vars->{'suggested_topic_size_lines'} =
	$Codestriker::suggested_topic_size_lines eq "" ? 0 :
	$Codestriker::suggested_topic_size_lines;    

    # Prepare the data for displaying the state update option.
    # Make sure the old mode setting is no longer used.
    if ((! defined $mode) || $mode == $Codestriker::NORMAL_MODE) {
	$mode = $Codestriker::COLOURED_MODE;
    }
    $vars->{'mode'} = $mode;
    $vars->{'topic_version'} = $topic->{version};
    $vars->{'states'} = \@Codestriker::topic_states;
    $vars->{'default_state'} = $topic->{state};

    # Obtain the topic description, with "Bug \d\d\d" links rendered to links
    # to the bug tracking system.
    my $data = "";
    for (my $i = 0; $i <= $#document_description; $i++) {
	$data .= $document_description[$i] . "\n";
    }
    $vars->{'description'} = $data;
    
    # Get the topic and user metrics.
    my @topic_metrics = $topic->get_metrics()->get_topic_metrics();
    $vars->{topic_metrics} = \@topic_metrics;

    my @author_metrics =
	$topic->get_metrics()->get_user_metrics($topic->{author});
    $vars->{author_metrics} = \@author_metrics;
    
    my @reviewer_list =
	$topic->get_metrics()->get_complete_list_of_topic_participants();

    # Remove the author from the list just in case somebody put
    # themselves in twice.
    @reviewer_list = grep { $_ ne $topic->{author} } @reviewer_list;

    my @reviewer_metrics;
    foreach my $reviewer (@reviewer_list)
    {
	my @user_metrics = $topic->get_metrics()->get_user_metrics($reviewer);

        # Make a copy, we don't want to modify the names in the
        # list. This is just for the consumption of the html
        # templates.
        my $reviewer_ui_name = $reviewer;
        $reviewer_ui_name = "(unknown user)" if ($reviewer eq "");

	my $metric = 
	{
	    reviewer => Codestriker->filter_email($reviewer_ui_name),
	    user_metrics => \@user_metrics
	};

	push @reviewer_metrics, $metric;
    }

    $vars->{reviewer_metrics} = \@reviewer_metrics;

    my @total_metrics = $topic->get_metrics()->get_user_metrics_totals(
                                            @reviewer_list, $topic->{author});
    $vars->{total_metrics} = \@total_metrics;

    my @topic_history = $topic->get_metrics()->get_topic_history();
    $vars->{activity_list} = \@topic_history;

    my $template = Codestriker::Http::Template->new("viewtopicinfo");
    $template->process($vars);

    $http_response->generate_footer();

    # Fire the topic listener to indicate that the user has viewed the topic.
    Codestriker::TopicListeners::Manager::topic_viewed($email, $topic);
}

1;
