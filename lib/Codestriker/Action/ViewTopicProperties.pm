###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the viewing of a topic's properties.

package Codestriker::Action::ViewTopicProperties;

use strict;

use Codestriker::Model::Topic;
use Codestriker::Model::Comment;
use Codestriker::Http::UrlBuilder;
use Codestriker::Http::Render;
use Codestriker::Repository::RepositoryFactory;
use HTML::Entities ();

# If the input is valid, display the topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    my $topicid = $http_input->get('topic');
    my $mode = $http_input->get('mode');
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
    my @topic_comments = $topic->read_comments();

    $http_response->generate_header($topic->{topicid},
				    $topic->{document_title}, 
    			            $topic->{author},
				    "", "", $mode, $tabwidth,
				    $topic->{repository}, "", "", 0, 1);

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

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    Codestriker::Action::ViewTopic::ProcessTopicHeader($vars, $topic,
						       $url_builder);

    # Get the total count of each type of comment for this topic.
    my @commentcounts;

    foreach my $state (@Codestriker::comment_states) {
	push @commentcounts, { name=>$state, count=>0 };
    }
    
    foreach my $comment (@topic_comments) {
	++$commentcounts[$comment->{state}]->{count};
    }

    $vars->{'commentcounts'} = \@commentcounts;   

    my @projectids = ($topic->{project_id});
    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [0], undef);
    $vars->{'list_url_in_project'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [0],
				      \@projectids);

    $vars->{'view_topic_url'} =
	$url_builder->view_url($topicid, -1, $mode);

    $vars->{'view_topicinfo_url'} = $url_builder->view_topicinfo_url($topicid);
    $vars->{'view_comments_url'} = $url_builder->view_comments_url($topicid);
    $vars->{'list_projects_url'} = $url_builder->list_projects_url();

    # Display the "update" message if the topic state has been changed.
    $vars->{'updated'} = $http_input->get('updated');
    $vars->{'rc_ok'} = $Codestriker::OK;
    $vars->{'rc_stale_version'} = $Codestriker::STALE_VERSION;
    $vars->{'rc_invalid_topic'} = $Codestriker::INVALID_TOPIC;
    
    $vars->{'bug_ids'} = $topic->{bug_ids};

    $vars->{'document_reviewers'} = 
    	Codestriker->filter_email($topic->{reviewers});

    # Indicate what repositories are available, and what the topic's
    # repository is.
    $vars->{'topic_repository'} = $topic->{repository};
    $vars->{'repositories'} = \@Codestriker::valid_repositories;

    # Indicate what projects are available, and what the topic's project is.
    my @projects = Codestriker::Model::Project->list();
    $vars->{'projects'} = \@projects;
    $vars->{'topic_projectid'} = $topic->{project_id};

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
    $vars->{'mode'} = $mode;
    $vars->{'topicid'} = $topic->{topicid};
    $vars->{'topic_version'} = $topic->{version};
    $vars->{'states'} = \@Codestriker::topic_states;
    $vars->{'default_state'} = $topic->{topic_state};

    # Obtain the topic description, with "Bug \d\d\d" links rendered to links
    # to the bug tracking system.
    my $data = "";
    for (my $i = 0; $i <= $#document_description; $i++) {
	$data .= $document_description[$i] . "\n";
    }
    $vars->{'description'} = $data;
    
    my $template = Codestriker::Http::Template->new("viewtopicproperties");
    $template->process($vars);

    $http_response->generate_footer();
}

1;
