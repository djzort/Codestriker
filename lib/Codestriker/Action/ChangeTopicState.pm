###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of changing a topic's state.

package Codestriker::Action::ChangeTopicState;

use strict;

# Attempt to change the topic's state, or to delete it.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $topic = $http_input->get('topic');
    my $button = $http_input->get('button');
    my $mode = $http_input->get('mode');
    my $version = $http_input->get('version');
    my $topic_state = $http_input->get('topic_state');
    my $email = $http_input->get('email');

    # Check if this action is allowed.
    if ($Codestriker::allow_delete == 0 && $button eq "Delete") {
	$http_response->error("This function has been disabled");
    }

    # Retrieve the appropriate topic details (for the bug_ids).
    my ($_document_author, $_document_title, $_document_bug_ids,
	$_document_reviewers, $_document_cc, $_description,
	$_topic_data, $_document_creation_time, $_document_modified_time,
	$_topic_state, $_version, $_repository);
    Codestriker::Model::Topic->read($topic, \$_document_author,
				    \$_document_title, \$_document_bug_ids,
				    \$_document_reviewers, \$_document_cc,
				    \$_description, \$_topic_data,
				    \$_document_creation_time,
				    \$_document_modified_time, \$_topic_state,
				    \$_version, \$_repository);
    # Update the topic's state.
    if ($button eq "Delete") {
	Codestriker::Model::Topic->delete($topic);
    } else {
	my $timestamp = Codestriker->get_timestamp(time);
	Codestriker::Model::Topic->change_state($topic, $topic_state,
						$timestamp, $version);
    }

    # If Codestriker is linked to a bug database, and this topic is associated
    # with some bugs, update them with an appropriate message.
    if ($_document_bug_ids ne "" && $Codestriker::bug_db ne "") {
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

    # Redirect the user to the view topic page if the topic wasn't deleted,
    # otherwise go to the list of open topics.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);
    my $redirect_url = "";
    if ($button eq "Delete") {
	if ($Codestriker::allow_searchlist) {
	    # Redirect to the topic list screen.
	    my @topic_states = (0);
	    $redirect_url =
		$url_builder->list_topics_url("", "", "", "", "", "", "",
					      "", "", \@topic_states);
	} else {
	    # Redirect to the create topic screen.
	    $redirect_url = $url_builder->create_topic_url();
	}
	
    } else {
	$redirect_url =
	    $url_builder->view_url_extended($topic, -1, $mode, "", "",
					    $query->url(), 1);
    }	
	
    print $query->redirect(-URI=>$redirect_url);
}

1;
