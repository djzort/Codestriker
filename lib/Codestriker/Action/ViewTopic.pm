###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the viewing of a topic.

package Codestriker::Action::ViewTopic;

use strict;

use Codestriker::Model::Topic;
use Codestriker::Model::Comment;
use Codestriker::Http::UrlBuilder;
use Codestriker::Http::Render;
use Codestriker::Repository::RepositoryFactory;
use Codestriker::TopicListeners::Manager;

# If the input is valid, display the topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    
    my $topicid = $http_input->get('topic');
    my $mode = $http_input->get('mode');
    my $brmode = $http_input->get('brmode');
    my $tabwidth = $http_input->get('tabwidth');
    my $email = $http_input->get('email');
    my $feedback = $http_input->get('feedback');

    if (Codestriker::Model::Topic::exists($topicid) == 0) {
	# Topic no longer exists, most likely its been deleted.
	$http_response->error("Topic no longer exists.");
    }

    # Retrieve the appropriate topic details.           
    my $topic = Codestriker::Model::Topic->new($topicid);     

    # Retrieve the changed files which are a part of this review.
    my (@filenames, @revisions, @offsets, @binary);
    Codestriker::Model::File->get_filetable($topicid,
    		\@filenames,
                \@revisions,
                \@offsets,
                \@binary);

    # Retrieve line-by-line versions of the data and description.
    my @document_description = split /\n/, $topic->{description};
    my @document = split /\n/, $topic->{document};

    # Retrieve the comment details for this topic.
    my @comments = $topic->read_comments();

    $http_response->generate_header($topic->{topicid}, $topic->{document_title}, 
    			            "",
				    "", "", $mode, $tabwidth,
				    "",
				    "", "", 0, 1);

    # Retrieve the repository object, if repository functionality is enabled.
    my $repository;
    if (scalar(@Codestriker::valid_repositories)) {
	$repository =
	    Codestriker::Repository::RepositoryFactory->get($topic->{repository});
    } else {
	# Indicate not to activate any repository-related links.
	$topic->{repository} = "";
    }

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'feedback'} = $feedback;

    # Create the necessary template variables for generating the heading part
    # of the view topic display.

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    ProcessTopicHeader($vars, $topic, $url_builder);

    my @projectids = ($topic->{project_id});
    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [0], undef);
    $vars->{'list_url_in_project'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [0],
				      \@projectids);

    # Display the "update" message if the topic state has been changed.
    $vars->{'updated'} = $http_input->get('updated');
    $vars->{'rc_ok'} = $Codestriker::OK;
    $vars->{'rc_stale_version'} = $Codestriker::STALE_VERSION;
    $vars->{'rc_invalid_topic'} = $Codestriker::INVALID_TOPIC;

    if ($topic->{bug_ids} ne "") {
	my @bugs = split ', ', $topic->{bug_ids};
	my $bug_string = "";
	for (my $i = 0; $i <= $#bugs; $i++) {
	    $bug_string .=
		$query->a({href=>"$Codestriker::bugtracker$bugs[$i]"},
			  $bugs[$i]);
	    $bug_string .= ', ' unless ($i == $#bugs);
	}
	$vars->{'bug_string'} = $bug_string;
    } else {
	$vars->{'bug_string'} = "";
    }

    $vars->{'document_reviewers'} = 
    	Codestriker->filter_email($topic->{reviewers});
    $vars->{'project_name'} = $topic->{project_name};
    $vars->{'number_of_lines'} = $#document + 1;

    $vars->{'suggested_topic_size_lines'} =
	$Codestriker::suggested_topic_size_lines eq "" ? 0 :
	$Codestriker::suggested_topic_size_lines;    
    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [ 0 ], undef);

    # Prepare the data for displaying the state update option.
    # Make sure the old mode setting is no longer used.
    if ((! defined $mode) || $mode == $Codestriker::NORMAL_MODE) {
	$mode = $Codestriker::COLOURED_MODE;
    }
    if (! defined $brmode) {
        $brmode = $Codestriker::default_topic_br_mode;
    }
    $vars->{'mode'} = $mode;
    $vars->{'brmode'} = $brmode;
    $vars->{'states'} = \@Codestriker::topic_states;
    $vars->{'default_state'} = $topic->{state};

    # Set the description of the topic.
    my $data = "";
    for (my $i = 0; $i <= $#document_description; $i++) {
	$data .= $document_description[$i] . "\n";
    }
    $vars->{'description'} = $data;


    # Obtain the link to download the actual document text.
    $vars->{'download_url'} = $url_builder->download_url($topicid);

    # Fire the template on the topic heading information.
    my $template = Codestriker::Http::Template->new("viewtopic");
    $template->process($vars);

    # The rest of the output is non-template driven, as it is quite
    # complex.

    # Give the user the option of swapping between diff view modes.
    # If there are no files associated with the review, remove this
    # option.
    my $coloured_url =
	$url_builder->view_url($topicid, -1, $Codestriker::COLOURED_MODE,
			       $brmode);
    my $coloured_mono_url =
	$url_builder->view_url($topicid, -1,
			       $Codestriker::COLOURED_MONO_MODE, $brmode);
    my $br_normal_url =
	$url_builder->view_url($topicid, -1, $mode,
			       $Codestriker::LINE_BREAK_NORMAL_MODE);
    my $br_assist_url =
	$url_builder->view_url($topicid, -1, $mode,
			       $Codestriker::LINE_BREAK_ASSIST_MODE);
	
    if ($mode == $Codestriker::COLOURED_MODE) {
	print "View as " .
	    $query->a({href=>$coloured_mono_url}, "coloured monospace diff") .
	    " | ";
    } elsif ($mode == $Codestriker::COLOURED_MONO_MODE) {
	print "View as " .
	    $query->a({href=>$coloured_url}, "coloured variable-width diff") .
	    " | ";
    }

    if ($brmode == $Codestriker::LINE_BREAK_NORMAL_MODE) {
	print "View with " .
	    $query->a({href=>$br_assist_url}, "minimal screen width") . ".";
    } elsif ($brmode == $Codestriker::LINE_BREAK_ASSIST_MODE) {
	print "View with " .
	    $query->a({href=>$br_normal_url}, "minimal line breaks") . ".";
    }
    print " | ";

    # Display the option to change the tab width.
    my $newtabwidth = ($tabwidth == 4) ? 8 : 4;
    my $change_tabwidth_url;
    $change_tabwidth_url =
	$url_builder->view_url_extended($topicid, -1, $mode, $newtabwidth,
					"", "", 0, $brmode);

    print "Tab width set to $tabwidth (";
    print $query->a({href=>"$change_tabwidth_url"},"change to $newtabwidth");
    print ")\n";

    print $query->p if ($mode == $Codestriker::NORMAL_MODE);

    # Number of characters the line number should take.
    my $max_digit_width = length($#document+1);

    # Build the render which will be used to build this page.
    my $render = Codestriker::Http::Render->new($query, $url_builder, 1,
						$max_digit_width, $topicid,
						$mode, \@comments, $tabwidth,
						$repository, \@filenames,
						\@revisions, \@binary, -1,
						$brmode);

    # Display the data that is being reviewed.
    $render->start();

    # Retrieve the delta set comprising this review.
    my @deltas = Codestriker::Model::File->get_delta_set($topicid);

    # Render the deltas.
    my $old_filename = "";
    for (my $i = 0; $i <= $#deltas; $i++) {
	my $delta =  $deltas[$i];

	$render->delta($delta);
    }

    $render->finish();

    # Render the HTML trailer.
    my $trailer = Codestriker::Http::Template->new("trailer");
    $trailer->process();

    print $query->end_html();

    $http_response->generate_footer();

    # Fire the topic listener to indicate that the user has viewed the topic.
    Codestriker::TopicListeners::Manager::topic_viewed($email, $topic);
}

# This function is used by all of the three topic pages to fill out the
# common template items that are required by all three.
sub ProcessTopicHeader($$$) {
    my ($vars, $topic, $url_builder) = @_;

    # Handle the links in the three topic tabs.
    $vars->{'view_topicinfo_url'} =
	$url_builder->view_topicinfo_url($topic->{topicid});
    $vars->{'view_topic_url'} =
         ## XX mode, last param
	$url_builder->view_url($topic->{topicid}, -1, 0);

    $vars->{'view_comments_url'} =
	$url_builder->view_comments_url($topic->{topicid});

    $vars->{'view_topic_properties_url'} =
	$url_builder->view_topic_properties_url($topic->{topicid});

    # Retrieve the comment details for this topic.
    my @comments = $topic->read_comments();

    # Obtains how many comments there are, and the internal link to them.
    $vars->{'number_comments'} = $#comments + 1;

    # Obtain the view topic summary information, the title, bugs it relates
    # to, and who the participants are.
    $vars->{'title'} = $topic->{title};

    $vars->{'author'} = Codestriker->filter_email($topic->{author});
    
    $vars->{'document_creation_time'} = 
    	Codestriker->format_timestamp($topic->{creation_ts});

    $vars->{'topic'} = $topic->{topicid};

    $vars->{'reviewers'} = Codestriker->filter_email($topic->{reviewers});
    $vars->{'cc'} =  Codestriker->filter_email($topic->{cc});
}

1;
