###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for the submission of changing multiple comment states.

package Codestriker::Action::SubmitEditCommentsState;

use strict;

use Codestriker::Action::ViewTopicComments;
use Codestriker::TopicListeners::Manager;

# Attempt to change the comment states, in particular the metrics associated
# with them.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    
    # Extract the values from the action.
    my $topicid = $http_input->get('topic');
    my $email = $http_input->get('email');
    
    if (Codestriker::Model::Topic::exists($topicid) == 0) {    
	# Topic no longer exists, most likely its been deleted.
	$http_response->error("Topic no longer exists.");
        return;
    }
    
    my $topic = Codestriker::Model::Topic->new($topicid);
    
    # Any feedback messages to the user.
    my $feedback = "";
    
    # Indicate if changes were made to stale comments.
    my $stale = 0;

    # The number of commentstates changed.
    my $comments_processed = 0;

    # Determine the mapping of comment state to version numbers, recorded
    # in the form submission, to ensure the versions being changed aren't
    # stale.
    my %comment_state_version_map = ();
    my %comment_state_new_map = ();
    foreach my $param_name ($query->param()) {
	foreach my $metric (@{$Codestriker::comment_state_metrics}) {
	    my $metric_name = $metric->{name};
	    my $prefix = "comment_state_metric\\|$metric_name";
	    if ($param_name =~ /^($prefix\|\-?\d+\|\-?\d+\|\d+)\|(\d+)$/) {
		$comment_state_version_map{$1} = $2;
		$comment_state_new_map{$1} = $query->param($param_name);
	    }
	}
    }
    
    # Go through all of the commentstate records, and change anything that
    # needs changing.
    my @topic_comments = $topic->read_comments();
    my %processed_commentstates = ();
    foreach my $comment (@topic_comments) {
	my $key = $comment->{filenumber} . "|" . $comment->{fileline} . "|" .
	    $comment->{filenew};
	if (! exists $processed_commentstates{$key}) {
	    # For each metric, see if there is a new value posted for this
	    # comment state.
	    my $state_changed = 0;
	    my $num_metrics_changed_for_comment_state = 0;
	    foreach my $metric (@{$Codestriker::comment_state_metrics}) {
		my $select_form_name =
		    "comment_state_metric|" . $metric->{name} . "|" . $key;

		# Check if this metric has a new value associated with it.
		my $current_metric_value =
		    $comment->{metrics}->{$metric->{name}};
		my $new_metric_value =
		    $comment_state_new_map{$select_form_name};
		if (defined $new_metric_value &&
		    $new_metric_value ne $current_metric_value) {
		    
		    # Change the specific metric for this commentstate record.
		    my $version =
			$comment_state_version_map{$select_form_name} +
			$num_metrics_changed_for_comment_state;
		    my $rc = $comment->change_state($metric->{name},
						    $new_metric_value,
						    $version);
		    if ($rc == $Codestriker::OK) {
			$state_changed = 1;
			$num_metrics_changed_for_comment_state++;
			Codestriker::TopicListeners::Manager::comment_state_change(
                                                 $email, $metric->{name},
						 $current_metric_value,
						 $new_metric_value, $topic,
						 $comment);
		    } elsif ($rc == $Codestriker::STALE_VERSION) {
			$stale = 1;
		    }
		}
	    }
	    if ($state_changed) {
		$comments_processed++;
	    }

	    # Indicate that this commentstate has been processed for all
	    # metrics.
	    $processed_commentstates{$key} = 1;
	}
    }
    
    # These message could be made more helpful in the future, but for now...
    if ($stale) {
	$feedback = "Some comments could not be updated as they have been " .
	    "modified by another user.";
    } else {
	if ($comments_processed == 1) {
	    $feedback = "Comment was successfully updated.";
	} elsif ($comments_processed > 1) {
	    $feedback = "$comments_processed comments were successfully updated.";
	}
    }

    # Direct control to the list comment action class, with the appropriate
    # feedback message.
    $http_input->{feedback} = $feedback;
    Codestriker::Action::ViewTopicComments->process($http_input,
						    $http_response);
}

1;
