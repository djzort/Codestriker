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

    # Retrieve the comment details for this topic.
    my @topic_comments = $topic->read_comments();

    $http_response->generate_header(topic=>$topic,
				    topic_title=>"Topic Properties: $topic->{title}",
				    mode=>$mode, tabwidth=>$tabwidth,
				    reload=>0, cache=>1);

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

    my @projectids = ($topic->{project_id});

    $vars->{'view_topic_url'} =
	$url_builder->view_url(topicid => $topicid, projectid => $topic->{project_id},
	                       mode => $mode);

    $vars->{'view_topicinfo_url'} = $url_builder->view_topicinfo_url(topicid => $topicid,
                                                                     projectid => $topic->{project_id});
    $vars->{'view_comments_url'} = $url_builder->view_comments_url(topicid => $topicid,
                                                                   projectid => $topic->{project_id});
    $vars->{'list_projects_url'} = $url_builder->list_projects_url();

    # Display the "update" message if the topic state has been changed.
    $vars->{'updated'} = $http_input->get('updated');
    $vars->{'rc_ok'} = $Codestriker::OK;
    $vars->{'rc_stale_version'} = $Codestriker::STALE_VERSION;
    $vars->{'rc_invalid_topic'} = $Codestriker::INVALID_TOPIC;

    # Store the bug id information, and any linking URLs.
    $vars->{'bug_db'} = $Codestriker::bug_db;
    $vars->{'bug_ids'} = $topic->{bug_ids};
    if (defined $topic->{bug_ids} && $topic->{bug_ids} ne "" &&
	defined $Codestriker::bugtracker) {
	my @bug_id_array = split /[\s,]+/, $topic->{bug_ids};
	$vars->{'bug_id_array'} = \@bug_id_array;
	$vars->{'bugtracker'} = $Codestriker::bugtracker;
    } else {
	$vars->{'bugtracker'} = '';
    }

    $vars->{'document_reviewers'} = 
    	Codestriker->filter_email($topic->{reviewers});

    # Indicate what repositories are available, and what the topic's
    # repository is.
    $vars->{'topic_repository'} = $Codestriker::repository_name_map->{$topic->{repository}};
    $vars->{'repositories'} = \@Codestriker::valid_repository_names;

    # Indicate what projects are available, and what the topic's project is.
    my @projects = Codestriker::Model::Project->list();
    $vars->{'projects'} = \@projects;
    $vars->{'project_states'} = \@Codestriker::project_states;
    $vars->{'projects_enabled'} = Codestriker->projects_disabled() ? 0 : 1;
    $vars->{'topic_projectid'} = $topic->{project_id};

    $vars->{'number_of_lines'} = $topic->get_topic_size_in_lines();

    $vars->{'suggested_topic_size_lines'} =
	$Codestriker::suggested_topic_size_lines eq "" ? 0 :
	$Codestriker::suggested_topic_size_lines;    

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
    $vars->{'description'} = $topic->{description};
    $vars->{'start_tag'} = $topic->{start_tag};
    $vars->{'end_tag'} = $topic->{end_tag};
    $vars->{'module'} = $topic->{module};

    my $template = Codestriker::Http::Template->new("viewtopicproperties");
    $template->process($vars);

    $http_response->generate_footer();

    # Fire the topic listener to indicate that the user has viewed the topic.
    Codestriker::TopicListeners::Manager::topic_viewed($email, $topic);
}

1;
