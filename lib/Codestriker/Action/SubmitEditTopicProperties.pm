###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of editing the properties of a
# topic.

package Codestriker::Action::SubmitEditTopicProperties;

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
    my $topic_title = $http_input->get('topic_title');
    my $topic_description = $http_input->get('topic_description');
    my $reviewers = $http_input->get('reviewers');
    my $email = $http_input->get('email');
    my $cc = $http_input->get('cc');
    my $topic_state = $http_input->get('topic_state');
    my $bug_ids = $http_input->get('bug_ids');
    my $repository_url = $http_input->get('repository');
    my $projectid = $http_input->get('projectid');

    # Check if this action is allowed.
    if ($Codestriker::allow_delete == 0 && $topic_state eq "Delete") {
	$http_response->error("This function has been disabled");
    }

    # Retrieve the current state of the topic.
    my $topic = Codestriker::Model::Topic->new($topicid);

    # Create a clone of this topic, which will contain the original state of
    # the topic, used for the topic listeners below.  Note we should really
    # have a clone() method but for now... XXX.
    my $topic_orig = Codestriker::Model::Topic->new($topicid);

    my $feedback = "";
    my $rc = $Codestriker::OK;

    # Make sure the topic being operated on is the most recent version.
    if ($topic->check_for_stale($version)) {
	$feedback .= "Topic properties have been modified by another user.";
    }

    # Check that the topic properties are valid.
    if ($topic_title eq "") {
	$feedback .= "Topic title cannot be empty.\n";
    }
    if ($topic_description eq "") {
	$feedback .= "Topic description cannot be empty.\n";
    }
    if ($email eq "") {
	$feedback .= "Author cannot be empty.\n";
    }
    if ($reviewers eq "") {
	$feedback .= "Reviewers cannot be empty.\n";
    }

    if ($feedback eq "") {
	if ($topic_state eq "Delete") {
	    $rc = $topic->delete();
	    if ($rc == $Codestriker::INVALID_TOPIC) {
		$feedback .= "Topic no longer exists.\n";
	    } elsif ($rc == $Codestriker::OK) {
		$feedback = "Topic has been deleted.";
	    }
	}
	else {
	    # The input looks good, update the database.
	    $rc = $topic->update($topic_title, $email, $reviewers, $cc,
				 $repository_url, $bug_ids, $projectid,
				 $topic_description, $topic_state);
	    if ($rc == $Codestriker::INVALID_TOPIC) {
		$feedback .= "Topic no longer exists.\n";
	    } elsif ($rc == $Codestriker::STALE_VERSION) {
		$feedback .=
		    "Topic was modified by another user, no changes done.\n";
	    } elsif ($rc == $Codestriker::OK) {
		$feedback .= "Topic properties successfully updated.\n";
	    }
	}

	# Fire the listeners.

    }

    # Indicate to the topic listeners that the topic has changed.
    Codestriker::TopicListeners::Manager::topic_changed($topic_orig, $topic);

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
	# Go to the view topic properties screen.
	Codestriker::Action::ViewTopicProperties->process($http_input,
							  $http_response);
    }	
}

1;
