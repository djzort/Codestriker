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
    $http_response->generate_header(topic => -1, topic_title=>"Project List",
				    reload=>0, cache=>0);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'feedback'} = $feedback;

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Go through all of the projects, and construct an edit_project URL.
    foreach my $project (@projects) {
	$project->{edit_url} = $url_builder->edit_project_url($project->{id});
    }
    $vars->{'projects'} = \@projects;

    $vars->{'create_project_url'} = $url_builder->create_project_url();

    # Send the data to the template for rendering.
    my $template = Codestriker::Http::Template->new("listprojects");
    $template->process($vars);

    $http_response->generate_footer();
}

1;
