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

# Attempt to change the comment states.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    
    # Extract the values from the action.
    my $comments_ref = $http_input->get('selected_comments');
    my @comments = @$comments_ref;
    my $comment_state = $http_input->get('comment_state');
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
    
    # Get the state number (index) for the new state name.
    my $state_id =
	Codestriker::Model::Comment::convert_state_to_stateid($comment_state);

    my @topic_comments = $topic->read_comments();
    
    # Apply the change to each commentstate.
    my %processed = ();
    if ($state_id != -1) {
	for (my $i = 0; $i <= $#comments; $i++) {
	    # Extract the line number and version of the comment that is being
	    # changed.
	    $comments[$i] =~ /^(.*)\,(.*)\,(.*)\,(.*)$/;
	    my $filenumber = $1;
	    my $fileline = $2;
	    my $filenew = $3;
	    my $version = $4;
	    my $key = "$filenumber,$fileline,$filenew";
            
            # Look for the comment comming from the CGI params, and update the
            # objects.  Make sure change_state is only called once per
	    # commentstate, not for each comment, as there can be many comments
	    # per commentstate object.
            foreach my $topic_comment (@topic_comments) {
            	if ($topic_comment->{filenumber} == $filenumber && 
		    $topic_comment->{fileline} == $fileline && 
		    $topic_comment->{filenew} == $filenew &&
		    (! exists $processed{$key}) &&
		    $topic_comment->{state} != $state_id) {
                    
		    # Change the comment state.
		    my $old_state_id = $topic_comment->{state};
                    my $rc = $topic_comment->change_state($state_id, $version);
		    $processed{$key} = 1;

		    if ($rc == $Codestriker::OK) {
			Codestriker::TopicListeners::Manager::comment_state_change($email, $old_state_id, $topic, $topic_comment);
		    } elsif ($rc == $Codestriker::STALE_VERSION) {
			# Record if there was a problem in changing the state.
			$stale = 1;
		    }
      		}
            }
	}
    }

    # These message could be made more helpful in the future, but for now...
    if ($stale) {
	$feedback = "Some comments could not be updated as they have been " .
	    "modified by another user.";
    } elsif ($state_id == -1) {
	$feedback = "Invalid comment state: \"$comment_state\".";
    } else {
	if ($#comments == 0) {
	    $feedback = "Comment was successfully updated.";
	} else {
	    $feedback = "All comments were successfully updated.";
	}
    }

    # Direct control to the list comment action class, with the appropriate
    # feedback message.
    $http_input->{feedback} = $feedback;
    Codestriker::Action::ViewTopicComments->process($http_input,
						    $http_response);
}

1;
