###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for editing a project.

package Codestriker::Action::EditProject;

use strict;
use Codestriker::Model::Project;

# Create an appropriate form for editing a project.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    # Check if this operation is allowed.
    if ($Codestriker::allow_projects == 0) {
	$http_response->error("This function has been disabled");
    }

    # Get the project id that is being edited.
    my $query = $http_response->get_query();
    my $projectid = $http_input->get('projectid');
    my $feedback = $http_input->get('feedback');
    $feedback =~ s/\n/<BR>/g;

    $http_response->generate_header("", "Edit project", "", "", "", "",
				    "", "", "", "", 0, 1);

    # Read the project information from the model.
    my $project = Codestriker::Model::Project->read($projectid);

    # Obtain a URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Construct the template object.
    my $vars = {};
    $vars->{'feedback'} = $feedback;
    $vars->{'project'} = $project;
    $vars->{'list_projects_url'} = $url_builder->list_projects_url();
    $vars->{'search_url'} = $url_builder->search_url();
    $vars->{'doc_url'} = $url_builder->doc_url();

    # Display the output via the template.
    my $template = Codestriker::Http::Template->new("editproject");
    $template->process($vars);

    $http_response->generate_footer();
}

1;
