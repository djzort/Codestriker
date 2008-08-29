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
    my $author = $http_input->get('author');
    my $cc = $http_input->get('cc');
    my $topic_state = $http_input->get('topic_state');
    my $bug_ids = $http_input->get('bug_ids');
    my $repository_name = $http_input->get('repository');
    my $projectid = $http_input->get('projectid');

    # Check if this action is allowed, and that the state is valid.
    if (! grep /^$topic_state$/, @Codestriker::topic_states) {
	$http_response->error("Topic state $topic_state unrecognised");
    }

    # Retrieve the current state of the topic.
    my $topic = Codestriker::Model::Topic->new($topicid);
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

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

    if ($Codestriker::antispam_email == 0) {
	if ($author eq "") {
	    $feedback .= "Author cannot be empty.\n";
	}
	if ($reviewers eq "") {
	    $feedback .= "Reviewers cannot be empty.\n";
	}
    } else {
	# Note if anti_spam email is on, don't allow the user to
	# change the $author, $reviewers or $cc properties.
	$author = $topic->{author};
	$reviewers = $topic->{reviewers};
	$cc = $topic->{cc};
    }

    # Make sure the repository value is correct.
    my $repository_url = '';
    if (defined $repository_name && $repository_name ne '') {
	$repository_url = $Codestriker::repository_url_map->{$repository_name};
	if ($repository_url eq "") {
	    $feedback .= "Repository name \"$repository_name\" is unknown.\n" .
		"Update your codestriker.conf file with this entry.\n";
	}
    }

    if ($feedback eq "") {
	# Create a clone of this topic, which will contain the
	# original state of the topic, and the proposed new state,
	# used for the topic listeners below.
	my $topic_orig = Codestriker::Model::Topic->new($topicid);
	my $topic_new = Codestriker::Model::Topic->new($topicid);

	if ($topic_state eq "Deleted") {
	    $rc = $topic->delete();
	    if ($rc == $Codestriker::INVALID_TOPIC) {
		$feedback .= "Topic no longer exists.\n";
	    } elsif ($rc == $Codestriker::OK) {
		$feedback = "Topic has been deleted.";
	    }
	}
	elsif ($topic_state eq "Obsoleted") {
	    # Redirect to the create topic screen with this topic being
	    # the one to obsolete.
	    my $create_topic_url =
		$url_builder->create_topic_url("$topicid,$version");
	    print $query->redirect(-URI=>$create_topic_url);
	    return;
	}
	else {
	    # Set the fields into the new topic object for checking.
	    $topic_new->{title} = $topic_title;
	    $topic_new->{author} = $author;
	    $topic_new->{reviewers} = $reviewers;
	    $topic_new->{cc} = $cc;
	    $topic_new->{repository} = $repository_url;
	    $topic_new->{bug_ids} = $bug_ids;
	    $topic_new->{project_id} = $projectid;
	    $topic_new->{description} = $topic_description;
	    $topic_new->{topic_state} = $topic_state;

	    # Make sure all the topic listeners are happy with this change
	    # before allowing it.
	    $feedback =
		Codestriker::TopicListeners::Manager::topic_pre_changed($email,
									$topic_orig,
									$topic_new);
	    if ($feedback eq '') {
		# Topic listeners are happy with this change.
		$rc = $topic->update($topic_title, $author, $reviewers, $cc,
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
	    else {
		$rc = $Codestriker::LISTENER_ABORT;
	    }
	}

	# Indicate to the topic listeners that the topic has changed.
	if ($rc == $Codestriker::OK) {
	    Codestriker::TopicListeners::Manager::topic_changed($email,
								$topic_orig,
								$topic);
	}
    }

    # Direct control to the appropriate action class, depending on the result
    # of the above operation, and what screens are enabled. The feedback
    # var is not html escaped in the template, so it must be done directly
    # with HTML::Entities::encode if needed.
    $feedback =~ s/\n/<BR>/g;
    $http_input->{feedback} = $feedback;
    if ($rc == $Codestriker::INVALID_TOPIC ||
	($rc == $Codestriker::OK && $topic_state eq "Deleted")) {
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
