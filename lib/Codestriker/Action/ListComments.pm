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
use HTML::Entities;

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
    my @comments = Codestriker::Model::Comment->read($topic);

    # Display the data, with each topic title linked to the view topic screen.
    $http_response->generate_header($topic, "Comment list", $email, "", "", "",
				    "", "", "", "", 0, 0);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'version'} = $Codestriker::VERSION;
    $vars->{'feedback'} = $feedback;

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Construct the view topic URL.
    my $view_url = $url_builder->view_url($topic, -1, $mode);
    $vars->{'view_topic_url'} = $view_url;

    # Construct the view comments URL.
    my $view_comments_url = $url_builder->view_comments_url($topic);
    $vars->{'view_comments_url'} = $view_comments_url;

    # Indicate where the documentation directory is.
    $vars->{'doc_url'} = $url_builder->doc_url();

    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [ 0 ], undef);
				      
    # Go through all the comments and make them into an appropriate form for
    # displaying.
    my $last_filenumber = -1;
    my $last_fileline = -1;
    my $index = 0;
    for (my $i = 0; $i <= $#comments; $i++) {
	my $comment = $comments[$i];

	if ($comment->{fileline} != $last_fileline ||
	    $comment->{filenumber} != $last_filenumber) {
	    my $new_file =
		$url_builder->view_file_url($topic, $comment->{filenumber},
					    $comment->{filenew},
					    $comment->{fileline}, $mode, 0);
					    
	    $comment->{view_file} =
		"javascript: myOpen('$new_file','CVS')";
	    my $parallel = 
		$url_builder->view_file_url($topic, $comment->{filenumber},
					    $comment->{filenew},
					    $comment->{fileline}, $mode, 1);
	    $comment->{view_parallel} =
		"javascript: myOpen('$parallel','CVS')";
	    $comment->{edit_url} =
		"javascript: eo('" . $comment->{filenumber} . "','" .
		$comment->{fileline} . "','" . $comment->{filenew} . "')";
	    $comment->{anchor} = $comment->{filenumber} . "|" .
		$comment->{fileline} . "|" . $comment->{filenew};
	    $last_fileline = $comment->{fileline};
	    $last_filenumber = $comment->{filenumber};
	}

	my $state = $comment->{state};
	$comment->{state} = $Codestriker::comment_states[$state];

	# Make sure the comment data is HTML escaped.
	$comment->{data} = HTML::Entities::encode($comment->{data});
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
    $template->process($vars);

    $http_response->generate_footer();
}

1;
