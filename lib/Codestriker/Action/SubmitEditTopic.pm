###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of changing a topic's state,
# metrics, and reviewer list.

package Codestriker::Action::SubmitEditTopic;

use strict;

use Codestriker::Model::Topic;
use Codestriker::Action::ListTopics;

# Attempt to change the topic's state, or to delete it.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $topicid = $http_input->get('topic');
    my $mode = $http_input->get('mode');
    my $version = $http_input->get('version');
    my $topic_state = $http_input->get('topic_state');
    my $email = $http_input->get('email');

    # Check if this action is allowed.
    if ($Codestriker::allow_delete == 0 && $topic_state eq "Delete") {
	$http_response->error("This function has been disabled");
    }

    my $topic = Codestriker::Model::Topic->new($topicid);    
    my $metrics = $topic->get_metrics();

    my $feedback;

    my @topic_metric = @{$http_input->get('topic_metric')};

    $feedback .= $metrics->verify_topic_metrics(@topic_metric);

    $metrics->set_topic_metrics(@topic_metric);

    $metrics->set_user_metric($topic->{author}, @{$http_input->{author_metric}});

    my @reviewer_list = split /, /, $topic->{reviewers};
    # Remove the author from the list just in case somebody put themselves in twice.
    @reviewer_list = grep { $_ ne $topic->{author} } @reviewer_list;

    for( my $userindex = 0; $userindex < scalar(@reviewer_list); ++$userindex)
    {
	my @usermetrics = @{$http_input->{"reviewer_metric, $userindex"}};

	$feedback .= $metrics->verify_user_metrics($reviewer_list[$userindex], @usermetrics);
	$metrics->set_user_metric($reviewer_list[$userindex], @usermetrics);
    }
    
    my @author_metrics = @{$http_input->get('author_metric')};
    $feedback .= $metrics->verify_user_metrics($topic->{author} , @author_metrics);
    $metrics->set_user_metric($topic->{author} , @author_metrics);
    
    $metrics->store();

    # Retrieve the appropriate topic details (for the bug_ids).
    # Update the topic's state.
    if ($topic_state eq "Delete") {
	Codestriker::TopicListeners::Manager::topic_delete($topic);
	$topic->delete();
	$feedback = "Topic has been deleted.";
    } else {
	if ($topic->check_for_stale($version))
	{
	    $feedback .= "Topic state has been modified by another user.";
	}
	else
	{
	    if ($feedback eq '')
	    {
		$feedback = "Topic state updated.";
	    }
	}

	Codestriker::TopicListeners::Manager::topic_state_change($topic, $topic_state);
	$topic->change_state($topic_state, $version);
    }

    my $rc = 0;

    # Direct control to the appropriate action class, depending on the result
    # of the above operation, and what screens are enabled.
    $http_input->{feedback} = $feedback;
    if ($rc == $Codestriker::INVALID_TOPIC || $topic_state eq "Delete") {
	if ($Codestriker::allow_searchlist) {
	    # Go to the topic list screen for just open topics.
	    $http_input->{sstate} = "0";
	    Codestriker::Action::ListTopics->process($http_input,
						     $http_response);
	} else {
	    # Go to the create topic screen.
	    Codestriker::Action::CreateTopic->process($http_input,
						      $http_response);
        }
    } else {
	# Go to the view topic screen.
	Codestriker::Action::ViewTopicInfo->process($http_input, $http_response);
    }	
}

1;
