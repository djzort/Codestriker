###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of changing multiple topic states.

package Codestriker::Action::ChangeTopics;

use strict;

use Codestriker::Action::ChangeTopicState;
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

    # Check if this action is allowed.
    if ($Codestriker::allow_delete == 0 && $button eq "Delete topics") {
	$http_response->error("This function has been disabled");
    }
    
    # Determine the "state" to change the group of topics to.
    my $change_state = ($button eq "Delete topics") ? "Delete" : $topic_state;

    # Any feedback messages to the user.
    my $feedback = "";

    # Indicate if changes were attempted on invalid topics.
    my $invalid = 0;

    # Indicate if changes were made to stale topics.
    my $stale = 0;

    # Apply the change to each topic.
    for (my $i = 0; $i <= $#topics; $i++) {
	# Extract the topic id and the version.
	$topics[$i] =~ /^(.*)\,(.*)$/;
	my $topic = $1;
	my $version = $2;

	# Change the topic state.
	my $rc =
	    Codestriker::Action::ChangeTopicState->change_state($query, $topic,
								$change_state,
								$version,
								$email);

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

1;
