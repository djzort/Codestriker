###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying a list of projects.

package Codestriker::Action::ListProjects;

use strict;
use Codestriker::Http::Template;
use Codestriker::Model::Project;

# List the projects in the system.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    # Check if this operation is allowed.
    if ($Codestriker::allow_projects == 0) {
	$http_response->error("This function has been disabled");
    }

    my $query = $http_response->get_query();
    my $feedback = $http_input->get('feedback');

    # Retrieve the project details.
    my @projects = Codestriker::Model::Project->list();

    # Display the data, with each prject title linked to edit project page.
    $http_response->generate_header(-1, "Project list", "", "", "", "",
				    "", "", "", "", 0, 0);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'version'} = $Codestriker::VERSION;
    $vars->{'feedback'} = $feedback;

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Go through all of the projects, and construct an edit_project URL.
    foreach my $project (@projects) {
	$project->{edit_url} = $url_builder->edit_project_url($project->{id});
    }
    $vars->{'projects'} = \@projects;

    # Store all of the URL objects.
    $vars->{'create_project_url'} = $url_builder->create_project_url();
    $vars->{'create_topic_url'} = $url_builder->create_topic_url();
    $vars->{'search_url'} = $url_builder->search_url();
    $vars->{'doc_url'} = $url_builder->doc_url();

    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [ 0 ], undef);
    
    # Send the data to the template for rendering.
    my $template = Codestriker::Http::Template->new("listprojects");
    $template->process($vars);

    $http_response->generate_footer();
}

1;
