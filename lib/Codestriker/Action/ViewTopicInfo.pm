###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the viewing of a topic.

package Codestriker::Action::ViewTopicInfo;

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

    $http_response->generate_header($topic->{topicid}, $topic->{document_title}, 
    			            $topic->{author},
				    "", "", $mode, $tabwidth, $topic->{repository},
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

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    Codestriker::Action::ViewTopic::ProcessTopicHeader($vars, $topic, $url_builder);

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
    $vars->{'repository'} = $topic->{repository};
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
    $vars->{'mode'} = $mode;
    $vars->{'topic_version'} = $topic->{version};
    $vars->{'states'} = \@Codestriker::topic_states;
    $vars->{'default_state'} = $topic->{state};

    # Obtain the topic description, with "Bug \d\d\d" links rendered to links
    # to the bug tracking system.
    my $data = "";
    for (my $i = 0; $i <= $#document_description; $i++) {
	$data .= $document_description[$i] . "\n";
    }
    $vars->{'description'} = $data;
    
    # Get the topic and user metrics.
    my @topic_metrics = $topic->get_metrics()->get_topic_metrics();
    $vars->{topic_metrics} = \@topic_metrics;

    my @author_metrics = $topic->get_metrics()->get_user_metrics($topic->{author});
    $vars->{author_metrics} = \@author_metrics;
    
    my @reviewer_list = split /, /, $topic->{reviewers};

    # Remove the author from the list just in case somebody put themselves in twice.
    @reviewer_list = grep { $_ ne $topic->{author} } @reviewer_list;

    my @reviewer_metrics;
    foreach my $reviewer (@reviewer_list)
    {
	my @user_metrics = $topic->get_metrics()->get_user_metrics($reviewer);

	my $metric = 
	{
	    reviewer => Codestriker->filter_email($reviewer),
	    user_metrics => \@user_metrics
	};

	push @reviewer_metrics, $metric;
    }

    $vars->{reviewer_metrics} = \@reviewer_metrics;

    my @total_metrics = $topic->get_metrics()->get_user_metrics_totals(@reviewer_list, $topic->{author});
    $vars->{total_metrics} = \@total_metrics;

    my $template = Codestriker::Http::Template->new("viewtopicinfo");
    $template->process($vars);

    $http_response->generate_footer();
}

1;
