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
    $http_response->generate_header("", "Create new topic", "", "", "", "",
				    "", "", "", "", 0, 1);

    # Obtain a URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'version'} = $Codestriker::VERSION;
    $vars->{'error_message'} = "";
    $vars->{'topic_text'} = "";
    $vars->{'topic_file'} = "";
    $vars->{'topic_description'} = "";
    $vars->{'topic_title'} = "";
    $vars->{'bug_ids'} = "";
    $vars->{'feedback'} = $http_input->get('feedback');
    
    # Indicate if project operations are enabled in the system.
    $vars->{'projects_enabled'} = $Codestriker::allow_projects;

    # Indicate if bug db integration is enabled.
    $vars->{'bugdb_enabled'} = ($Codestriker::bug_db ne "") ? 1 : 0;

    # Indicate where the documentation directory and generate the search
    # url.
    $vars->{'doc_url'} = $url_builder->doc_url();
    $vars->{'search_url'} = $url_builder->search_url();

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

    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [ 0 ], undef);

    # Indicate if the repository field should be displayed.
    $vars->{'allow_repositories'} = $Codestriker::allow_repositories;

    # Set the default repository to select.
    if (! (defined $vars->{'default_repository'}) ||
	$vars->{'default_repository'} eq "") {
	if ($#Codestriker::valid_repositories != -1) {
	    # Choose the first repository as the default selection.
	    $vars->{'default_repository'} =
		$Codestriker::valid_repositories[0];
	}
    }

    # Indicate the list of valid repositories which can be choosen.
    $vars->{'repositories'} = \@Codestriker::valid_repositories;

    # Read the list of projects available to make that choice available
    # when a topic is created.
    my @projects = Codestriker::Model::Project->list();
    $vars->{'projects'} = \@projects;

    my $template = Codestriker::Http::Template->new("createtopic");
    $template->process($vars);

    $http_response->generate_footer();
}

1;
