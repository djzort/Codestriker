###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for the submission of changing multiple comment states.

package Codestriker::Action::ChangeComments;

use strict;

# Attempt to change the comment states.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Extract the values from the action.
    my $comments_ref = $http_input->get('selected_comments');
    my @comments = @$comments_ref;
    my $comment_state = $http_input->get('comment_state');
    my $topic = $http_input->get('topic');

    # Any feedback messages to the user.
    my $feedback = "";

    # Indicate if changes were made to stale comments.
    my $stale = 0;

    # Map the state name to its number.
    my $stateid = -1;
    my $id;
    for ($id = 0; $id <= $#Codestriker::comment_states; $id++) {
	last if ($Codestriker::comment_states[$id] eq $comment_state);
    }
    if ($id <= $#Codestriker::comment_states) {
	$stateid = $id;
    }
    
    # Apply the change to each topic.
    if ($stateid != -1) {
	for (my $i = 0; $i <= $#comments; $i++) {
	    # Extract the line number and version of the comment that is being
	    # changed.
	    $comments[$i] =~ /^(.*)\,(.*)\,(.*)\,(.*)$/;
	    my $filenumber = $1;
	    my $fileline = $2;
	    my $filenew = $3;
	    my $version = $4;
	    
	    # Change the comment state.
	    my $timestamp = Codestriker->get_timestamp(time);
	    my $rc =
		Codestriker::Model::Comment->change_state($topic,
							  $fileline,
							  $filenumber,
							  $filenew,
							  $stateid,
							  $version);

	    # Record if there was a problem in changing the state.
	    $stale = 1 if $rc == $Codestriker::STALE_VERSION;
	}
    }

    # These message could be made more helpful in the future, but for now...
    if ($stale) {
	$feedback = "Some comments could not be updated as they have been " .
	    "modified by another user.";
    } elsif ($stateid == -1) {
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
    Codestriker::Action::ListComments->process($http_input, $http_response);
}

1;
