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
use Codestriker::Http::Render;
use Codestriker::Model::Comment;
use Codestriker::Model::File;
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
    my $show_context = $http_input->get('scontext');
    my $show_comments_from_user = $http_input->get('sauthor');
    my $show_comments_by_state  = $http_input->get('sstate');
    
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
				      
    # Filter out comments that the user has said they don't want to see.
    my %usersThatHaveComments;
    
    @comments = grep { 
        my $comment = $_;
        my $keep_comment = 1;
                        
        # check for filter via the state of the comment.
        $keep_comment = 0 if ( $show_comments_by_state ne ""  && 
                               $show_comments_by_state ne $comment->{state} );
        
        # check for filters via the comment author name.
        if ($Codestriker::antispam_email) {
            my $shortAuthor = 
            		Codestriker->make_antispam_email( $comment->{author} );
            my $shortFilterAuthor = 
            		Codestriker->make_antispam_email( $show_comments_from_user );
            $keep_comment = 0 if ( $show_comments_from_user ne "" && 
                                   $shortAuthor ne $shortFilterAuthor);
                                   
            # Make a list of users while we are at it.
            $usersThatHaveComments{$shortAuthor } = 1;                                   
        }
        else {
            $keep_comment = 0 if ( $show_comments_from_user ne "" && 
                                  $comment->{author} ne $show_comments_from_user);
                                  
            # Make a list of users while we are at it.
            $usersThatHaveComments{$comment->{author}} = 1;                                  
        }
                                               
                      
 	$keep_comment;
    } @comments;
    
    # Filter the email address out, in the object.
    if ( $Codestriker::antispam_email ) {
    	foreach my $comment (@comments) {
    	    $comment->{author} = Codestriker->make_antispam_email( $comment->{author} );
        }
    }     
                                         
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
        
        if ($show_context ne "" && $show_context > 0) {
                my $new = 1;        
                my $delta = Codestriker::Model::File->get_delta($topic, 
                                $comment->{filenumber}, 
                                $comment->{fileline} , 
                                $new);

                $comment->{context} = Codestriker::Http::Render->get_context(
                                                $comment->{fileline} , 
                                                $show_context, 1,
                                                $delta->{old_linenumber},
                                                $delta->{new_linenumber},
                                                $delta->{text}, 
                                                $new);
       }
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
    
    my @usersThatHaveCommentsList = sort keys %usersThatHaveComments;
    $vars->{'users'} = \@usersThatHaveCommentsList;
    
    # Push in the current filter combo box selections so the window remembers
    # what the user has currently set.
    $vars->{'scontext'} = $show_context;    
    if ( $show_comments_by_state ne '') {
    	$vars->{'select_sstate'} = $show_comments_by_state + 1;
    }
    else {
    	$vars->{'select_sstate'} = 0;
    }
 
    $vars->{'sstate'} = $show_comments_by_state;     
    $vars->{'sauthor'} = $http_input->get('sauthor');

    # Send the data to the template for rendering.
    my $template = Codestriker::Http::Template->new("displaycomments");
    $template->process($vars);

    $http_response->generate_footer();
}

1;
