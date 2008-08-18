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
    my $fview = $http_input->get('fview');
    my $tabwidth = $http_input->get('tabwidth');
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
    my $projectid = $topic->{project_id};     

    # Display the data, with each topic title linked to the view topic screen.
    $http_response->generate_header(topic=>$topic,
				    comments=>\@comments,
				    topic_title=>"Topic Comments: $topic->{title}",
				    email=>$email, fview=>$fview,
				    tabwidth=>$tabwidth,
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
    my $last_filenumber = -999;
    my $last_fileline = -999;
    my $index = 0;
    for (my $i = 0; $i <= $#comments; $i++) {
	my $comment = $comments[$i];

	if ($comment->{fileline} != $last_fileline ||
	    $comment->{filenumber} != $last_filenumber) {
	    my $new_file =
		$url_builder->view_file_url(topicid => $topicid, projectid => $projectid,
		                            filenumber => $comment->{filenumber},
					                new => $comment->{filenew},
					                line => $comment->{fileline}, mode => $mode);
					    
	    $comment->{view_file} = "javascript: myOpen('$new_file','CVS')";
	    my $parallel = $new_file;
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

        if (defined $show_context && $show_context ne "" &&
            $show_context > 0 &&
	    $comment->{filenumber} != -1 && $comment->{fileline} != -1) {
                my $delta = Codestriker::Model::Delta->get_delta($topicid, 
                                $comment->{filenumber}, 
                                $comment->{fileline} , 
                                $comment->{filenew});

		my @text = ();
		my $offset = $delta->retrieve_context($comment->{fileline}, $comment->{filenew},
						      $show_context, \@text);
		for (my $i = 0; $i <= $#text; $i++) {
		    $text[$i] = HTML::Entities::encode($text[$i]);
		    if ($i == $offset) {
			$text[$i] = "<font color=\"red\">" . $text[$i] . "</font>";
		    }
		}
                $comment->{context} = $offset == -1 ? "" : (join "\n", @text);
       }
    }

    # Store the parameters to the template.
    $vars->{'email'} = $email;
    $vars->{'comments'} = \@comments;
    $vars->{'users'} = \@usersThatHaveComments;
    $vars->{'tabwidth'} = $tabwidth;
    
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

    # Store the topic status     
    $vars->{'default_state'} = $topic->{topic_state};     
    $vars->{'topic_states'} = \@Codestriker::topic_states; 

    # Send the data to the template for rendering.
    my $template = Codestriker::Http::Template->new("viewtopiccomments");
    $template->process($vars);

    $http_response->generate_footer();

    # Fire the topic listener to indicate that the user has viewed the topic.
    Codestriker::TopicListeners::Manager::topic_viewed($email, $topic);
}

1;
