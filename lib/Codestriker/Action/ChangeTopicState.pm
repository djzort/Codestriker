###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of changing a topic's state.

package Codestriker::Action::ChangeTopicState;

use strict;

use Codestriker::Model::Topic;
use Codestriker::Action::ListTopics;

# Attempt to change the topic's state, or to delete it.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $topic = $http_input->get('topic');
    my $mode = $http_input->get('mode');
    my $version = $http_input->get('version');
    my $topic_state = $http_input->get('topic_state');
    my $email = $http_input->get('email');

    # Check if this action is allowed.
    if ($Codestriker::allow_delete == 0 && $topic_state eq "Delete") {
	$http_response->error("This function has been disabled");
    }

    my $rc = $type->change_state($query, $topic, $topic_state, $version, $email);

    # Set the feedback message to the user.
    my $feedback = "";
    if ($rc == $Codestriker::OK) {
	if ($topic_state eq "Delete") {
	    $feedback = "Topic has been deleted.";
	} else {
	    $feedback = "Topic state updated.";
	}
    } elsif ($rc == $Codestriker::STALE_VERSION) {
	$feedback = "Topic state has been modified by another user.";
    } elsif ($rc == $Codestriker::INVALID_TOPIC) {
	$feedback = "Topic no longer exists.";
    }

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
	Codestriker::Action::ViewTopic->process($http_input, $http_response);
    }	
}

# Change the specified topic to the specified topic state, or delete it if
# it is "Delete".  If Bugzilla connectivity is set, update the associated bugs.
# This method is also used by the ChangeTopics action.
sub change_state($$$$$$) {
    my ($type, $query, $topic, $topic_state, $version, $email) = @_;

    # Retrieve the appropriate topic details (for the bug_ids).
    my ($_document_author, $_document_title, $_document_bug_ids,
	$_document_reviewers, $_document_cc, $_description,
	$_topic_data, $_document_creation_time, $_document_modified_time,
	$_topic_state, $_version, $_repository);
    my $rc = Codestriker::Model::Topic->read($topic, \$_document_author,
					     \$_document_title,
					     \$_document_bug_ids,
					     \$_document_reviewers,
					     \$_document_cc,
					     \$_description, \$_topic_data,
					     \$_document_creation_time,
					     \$_document_modified_time,
					     \$_topic_state,
					     \$_version, \$_repository);
    
    return $rc if $rc != $Codestriker::OK;

    # Update the topic's state.
    if ($topic_state eq "Delete") {
	$rc = Codestriker::Model::Topic->delete($topic);
    } else {
	my $timestamp = Codestriker->get_timestamp(time);
	$rc = Codestriker::Model::Topic->change_state($topic, $topic_state,
						      $timestamp, $version);
    }

    # If Codestriker is linked to a bug database, and this topic is associated
    # with some bugs, update them with an appropriate message.
    if ($rc == $Codestriker::OK &&
	$_document_bug_ids ne "" && $Codestriker::bug_db ne "") {
	my $bug_db_connection =
	    Codestriker::BugDB::BugDBConnectionFactory->getBugDBConnection();
	$bug_db_connection->get_connection();
	my @ids = split /, /, $_document_bug_ids;
	my $url_builder = Codestriker::Http::UrlBuilder->new($query);
	my $topic_url = $url_builder->view_url_extended($topic, -1, "", "",
							"", $query->url(), 0);
	my $text = "Codestriker topic: $topic_url\n" .
	    "State changed to \"$topic_state\" by $email.\n";
	for (my $i = 0; $i <= $#ids; $i++) {
	    $bug_db_connection->update_bug($ids[$i], $text);
	}
	$bug_db_connection->release_connection();
    }

    # Indicate the success of this operation to the client.
    return $rc;
}

1;
