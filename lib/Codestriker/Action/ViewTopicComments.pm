###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying a list of comments.

package Codestriker::Action::ViewTopicComments;

use strict;
use Codestriker::Http::Template;
use Codestriker::Http::Render;
use Codestriker::Model::Comment;
use Codestriker::Model::File;

# If the input is valid, list the appropriate comments for a topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $topicid = $http_input->get('topic');
    my $email = $http_input->get('email');
    my $mode = $http_input->get('mode');
    my $feedback = $http_input->get('feedback');
    my $show_context = $http_input->get('scontext');
    my $show_comments_from_user = $http_input->get('sauthor');
    
    # Retrieve the filter parameters from the metrics, if any.
    my %metric_filter = ();
    foreach my $comment_state_metric (@{$Codestriker::comment_state_metrics}) {
	my $name = "comment_state_metric_" . $comment_state_metric->{name};
	my $value = $http_input->get($name);
	if (defined $value && $value ne "__any__") {
	    $metric_filter{$comment_state_metric->{name}} = $value;
	}
    }

    # Retrieve the comment details for this topic.
    my @comments =
	Codestriker::Model::Comment->read_filtered($topicid,
						   $show_comments_from_user,
						   \%metric_filter);

    # Retrieve the appropriate topic details.           
    my $topic = Codestriker::Model::Topic->new($topicid);     

    # Display the data, with each topic title linked to the view topic screen.
    $http_response->generate_header(topic=>$topicid,
				    topic_title=>"Topic Comments: $topic->{title}",
				    email=>$email, 
                                    reload=>0, cache=>0);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'feedback'} = $feedback;

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    Codestriker::Action::ViewTopic::ProcessTopicHeader($vars, $topic,
						       $url_builder);

    # Get the list of users that have put comments in against the
    # comment, and filter if needed.
    my @usersThatHaveComments =
	Codestriker::Model::Comment->read_authors($topicid);
    @usersThatHaveComments = map 
            { Codestriker->filter_email($_) } 
            @usersThatHaveComments;        
    
    # Filter the email address out, in the object.
    foreach my $comment (@comments) {
    	$comment->{author} = Codestriker->filter_email($comment->{author});
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
		$url_builder->view_file_url($topicid, $comment->{filenumber},
					    $comment->{filenew},
					    $comment->{fileline}, $mode, 0);
					    
	    $comment->{view_file} = "javascript: myOpen('$new_file','CVS')";
	    my $parallel = 
		$url_builder->view_file_url($topicid, $comment->{filenumber},
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

        if ($show_context ne "" && $show_context > 0) {
                my $delta = Codestriker::Model::Delta->get_delta($topicid, 
                                $comment->{filenumber}, 
                                $comment->{fileline} , 
                                $comment->{filenew});

                $comment->{context} = Codestriker::Http::Render->get_context(
                                                $comment->{fileline} , 
                                                $show_context, 1,
                                                $delta->{old_linenumber},
                                                $delta->{new_linenumber},
                                                $delta->{text}, 
                                                $comment->{filenew});
       }
    }

    # Store the parameters to the template.
    $vars->{'email'} = $email;
    $vars->{'comments'} = \@comments;
    $vars->{'users'} = \@usersThatHaveComments;
    
    # Push in the current filter combo box selections so the window remembers
    # what the user has currently set.
    $vars->{'scontext'} = $show_context;
    $vars->{'sauthor'} = $http_input->get('sauthor');
    $vars->{'metrics_selection'} = \%metric_filter;

    # Store the metrics configuration into the template so it knows
    # how to render the dropdowns.
    my @metrics = ();
    foreach my $metric_config (@{ $Codestriker::comment_state_metrics }) {
	my $metric_data = {};
	$metric_data->{name} = $metric_config->{name};
	$metric_data->{values} = $metric_config->{values};
	push @metrics, $metric_data;
    }
    $vars->{'metrics'} = \@metrics;

    # Send the data to the template for rendering.
    my $template = Codestriker::Http::Template->new("viewtopiccomments");
    $template->process($vars);

    $http_response->generate_footer();

    # Fire the topic listener to indicate that the user has viewed the topic.
    Codestriker::TopicListeners::Manager::topic_viewed($email, $topic);
}

1;
