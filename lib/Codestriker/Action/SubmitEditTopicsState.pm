###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of changing multiple topic states.

package Codestriker::Action::SubmitEditTopicsState;

use strict;

use Codestriker::Action::ListTopics;

# Attempt to change the topic's state, or to delete it.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $topics_ref = $http_input->get('selected_topics');
    my @topics = @$topics_ref;

    my $topic_state = $http_input->get('topic_state');
    my $email = $http_input->get('email');
    my $button = $http_input->get('button');

    # Check if this is an obsolete function, and if so, redirect to the
    # create topic screen.
    if ($button eq "Obsolete Topic(s)") {
	my $url_builder = Codestriker::Http::UrlBuilder->new($query);
	my $create_topic_url =
	    $url_builder->create_topic_url((join ',', @topics));
	print $query->redirect(-URI=>$create_topic_url);
	return;
    }

    # The main topic list page does not allow deletes, so block this out.
    if ($topic_state eq "Deleted") {
	$http_response->error("This function has been disabled");
    }
    
    # Any feedback messages to the user.
    my $feedback = "";

    # Indicate if changes were attempted on invalid topics.
    my $invalid = 0;

    # Indicate if changes were made to stale topics.
    my $stale = 0;

    # Apply the change to each topic.
    for (my $i = 0; $i <= $#topics; $i++) {
	# Extract the topic id and the version.
	$topics[$i] =~ /^([0-9]+)\,([0-9]+)$/;

        # Dump the request if the param does not look right.
        next if (!defined($1) || !defined($2));

	my $topicid = $1;
	my $version = $2;

	my $rc = $type->update_state($topicid, $version, $topic_state, $email);

	# Record if there was a problem in changing the state.
	$invalid = 1 if $rc == $Codestriker::INVALID_TOPIC;
	$stale = 1 if $rc == $Codestriker::STALE_VERSION;
    }

    # These message could be made more helpful in the future, but for now...
    if ($invalid && $stale) {
	$feedback = "Some topics could not be updated as they were either " .
	    "modified by another user, or no longer exist.";
    } elsif ($invalid) {
	$feedback = "Some topics could not be updated as they no longer " .
	    "exist.";
    } elsif ($stale) {
	$feedback = "Some topics could not be updated as they have been " .
	    "modified by another user.";
    } else {
	if ($#topics == 0) {
	    $feedback = "Topic was successfully updated.";
	} else {
	    $feedback = "All topics were successfully updated.";
	}
    }

    # Direct control to the list topic action class, with the appropriate
    # feedback message.
    $http_input->{feedback} = $feedback;
    Codestriker::Action::ListTopics->process($http_input, $http_response);
}

# Static method for updating the state of a topic, and informing all of the
# topic listeners.
sub update_state {
    my ($type, $topicid, $version, $topic_state, $email) = @_;

    # Original topic object which won't be changed in the
    # change_state operation.
    my $topic_orig = Codestriker::Model::Topic->new($topicid);

    # Don't do anything if the topic is already at the given state.
    return $Codestriker::OK if ($topic_state eq $topic_orig->{topic_state});

    # Topic object to operate on.
    my $topic = Codestriker::Model::Topic->new($topicid);
    my $rc = $Codestriker::OK;
    if ($topic->{version} == $version) {
	# Change the topic state.
	$rc = $topic->change_state($topic_state);
    } else {
	# Stale version.
	$rc = $Codestriker::STALE_VERSION;
    }

    if ($rc == $Codestriker::OK) {
	# Fire a topic changed listener event.
	my $topic_new = Codestriker::Model::Topic->new($topicid);
	Codestriker::TopicListeners::Manager::topic_changed($email,
							    $topic_orig,
							    $topic_new);
    }

    # Indicate whether the operation was successful or not.
    return $rc;
}

1;
