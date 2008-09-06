###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying the create topic form.

package Codestriker::Action::CreateTopic;

use strict;
use Codestriker::Http::Cookie;
use Codestriker::Model::Project;

# Create an appropriate form for creating a new topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    my $obsoletes = $http_input->get('obsoletes');
    $http_response->generate_header(topic_title=>"Create New Topic",
                                    reload=>0, cache=>1);

    # Obtain a URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'error_message'} = "";
    $vars->{'topic_text'} = "";
    $vars->{'topic_file'} = "";
    $vars->{'topic_description'} = "";
    $vars->{'topic_title'} = $http_input->get('topic_title');
    $vars->{'bug_ids'} = $http_input->get('bug_ids');
    $vars->{'states'} = \@Codestriker::topic_states;
    $vars->{'feedback'} = $http_input->get('feedback');
    $vars->{'default_to_head'} = "";

    # Indicate where the documentation directory and generate the search
    # url.
    $vars->{'doc_url'} = $url_builder->doc_url();
    $vars->{'search_url'} = $url_builder->search_url();

    # TODO: fix this once create topic is only done within context of a project.
    $vars->{'action_url'} = $url_builder->add_topic_url(projectid => 0);

    # Retrieve the email, reviewers, cc, repository and projectid from
    # the cookie.
    $vars->{'email'} =
      Codestriker::Http::Cookie->get_property($query, 'email');
    $vars->{'reviewers'} =
      Codestriker::Http::Cookie->get_property($query, 'reviewers');
    $vars->{'cc'} =
      Codestriker::Http::Cookie->get_property($query, 'cc');
    $vars->{'default_repository'} =
      Codestriker::Http::Cookie->get_property($query, 'repository');
    $vars->{'default_projectid'} =
      Codestriker::Http::Cookie->get_property($query, 'projectid');

    # Set the default repository to select.
    if (! (defined $vars->{'default_repository'}) ||
        $vars->{'default_repository'} eq "") {
        if ($#Codestriker::valid_repository_names != -1) {
            # Choose the first repository as the default selection.
            $vars->{'default_repository'} =
              $Codestriker::valid_repository_names[0];
        }
    }

    # Indicate the list of valid repositories which can be choosen.
    $vars->{'repositories'} = \@Codestriker::valid_repository_names;

    # Read the list of projects available to make that choice available
    # when a topic is created.
    my @projects = Codestriker::Model::Project->list('Open');
    $vars->{'projects'} = \@projects;

    # If this create topic action obsoletes some topics, then get their
    # details now.  For now, don't check if a topic is stale with the
    # version parameter.
    $vars->{'obsoletes'} = $obsoletes;
    if ($type->set_obsoleted_topics_parameter($vars, $url_builder) == -1) {
        $http_response->error("Obsoleted topic no longer exists.");
    }

    my $template = Codestriker::Http::Template->new("createtopic");
    $template->process($vars);

    $http_response->generate_footer();
}

# Set the obsoleted_topics parameter correctly into $vars.  Return -1 if
# there was a failure.
sub set_obsoleted_topics_parameter {
    my ($type, $vars, $url_builder) = @_;

    my $obsoletes = $vars->{'obsoletes'};
    my @obsoleted_topics = ();
    if (defined $obsoletes and $obsoletes ne '') {
        my @topics = split ',', $obsoletes;
        for (my $i = 0; $i <= $#topics; $i+=2) {
            my $topicid = $topics[$i];
            if (Codestriker::Model::Topic::exists($topicid) == 0) {
                return -1;
            }
            my $topic = Codestriker::Model::Topic->new($topicid);
            my $obsoleted_topic = {};
            $obsoleted_topic->{title} = $topic->{title};
            $obsoleted_topic->{view_url} = $url_builder->view_url(topicid => $topicid,
                                                                  projectid => $topic->{project_id});
            push @obsoleted_topics, $obsoleted_topic;
        }
    }
    $vars->{'obsoleted_topics'} = \@obsoleted_topics;
    return 0;
}

1;
