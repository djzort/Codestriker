###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying a list of comments.

package Codestriker::Action::ListComments;

use strict;
use Codestriker::Http::Template;

# If the input is valid, list the appropriate comments for a topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $topic = $http_input->get('topic');
    my $email = $http_input->get('email');
    my $mode = $http_input->get('mode');
    my $feedback = $http_input->get('feedback');
    
    # Perform some error checking here on the parameters.

    # Retrieve the comment details for this topic.
    my (@comments, %comment_exists);
    my $rc = Codestriker::Model::Comment->read($topic,
					       \@comments,
					       \%comment_exists);

    if ($rc == $Codestriker::INVALID_TOPIC) {
	# Topic no longer exists, most likely its been deleted.
	$http_response->error("Topic no longer exists.");
    }

    # Display the data, with each topic title linked to the view topic screen.
    $http_response->generate_header($topic, "Comment list", $email, "", "", "",
				    "", "", "", 0, 0);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'feedback'} = $feedback;

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Construct the view topic URL.
    my $view_url = $url_builder->view_url($topic, -1, $mode);
    $vars->{'view_topic_url'} = $view_url;

    # Construct the view comments URL.
    my $view_comments_url = $url_builder->view_comments_url($topic);
    $vars->{'view_comments_url'} = $view_comments_url;

    # Go through all the comments and make them into an appropriate form for
    # displaying.
    my $last_line = -1;
    my $index = 0;
    for (my $i = 0; $i <= $#comments; $i++) {
	if ($comments[$i]{line} != $last_line) {
	    my $new_file =
		$url_builder->view_file_url($topic, $comments[$i]{filename},
					    $UrlBuilder::NEW_FILE,
					    $comments[$i]{fileline}, "",
					    $mode);
	    $comments[$i]{view_file} =
		"javascript: myOpen('$new_file','CVS')";
	    my $parallel = 
		$url_builder->view_file_url($topic, $comments[$i]{filename},
					    $UrlBuilder::BOTH_FILES,
					    $comments[$i]{fileline}, "",
					    $mode);
	    $comments[$i]{view_parallel} =
		"javascript: myOpen('$parallel','CVS')";
	    my $edit_url =
		$url_builder->edit_url($comments[$i]{line}, $topic, "",
				       $comments[$i]{line}, "");
	    $comments[$i]{edit_url} =
		"javascript: myOpen('$edit_url','e')";
	    $last_line = $comments[$i]{line};
	}

	my $state = $comments[$i]{state};
	$comments[$i]{state} = $Codestriker::comment_states[$state];
    }

    # Indicate what states the comments can be transferred to.
    my @states = ();
    for (my $i = 0; $i <= $#Codestriker::comment_states; $i++) {
	my $state = $Codestriker::comment_states[$i];
	if ($state ne "Draft" && $state ne "Deleted") {
	    push @states, $state;
	}
    }

    # Store the parameters to the template.
    $vars->{'topic'} = $topic;
    $vars->{'email'} = $email;
    $vars->{'comments'} = \@comments;
    $vars->{'states'} = \@states;

    # Send the data to the template for rendering.
    my $template = Codestriker::Http::Template->new("displaycomments");
    $template->process($vars) || die $template->error();
}

1;
