###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying the create project form.

package Codestriker::Action::CreateProject;

use strict;
use Codestriker;
use Codestriker::Http::Cookie;

# Create an appropriate form for creating a new project.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    # Check if this operation is allowed.
    if (Codestriker->projects_disabled()) {
	$http_response->error("This function has been disabled");
    }

    my $query = $http_response->get_query();
    my $feedback = $http_input->get('feedback');
    $feedback =~ s/\n/<BR>/g;

    $http_response->generate_header(topic_title=>"Create New Project",
				    reload=>0, cache=>1);

    # Obtain a URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'error_message'} = "";
    $vars->{'project_name'} = $http_input->get('project_name');
    $vars->{'project_description'} = $http_input->get('project_description');
    $vars->{'feedback'} = $feedback;
    $vars->{'list_projects_url'} = $url_builder->list_projects_url();
    $vars->{'search_url'} = $url_builder->search_url();
    $vars->{'doc_url'} = $url_builder->doc_url();

    my $template = Codestriker::Http::Template->new("createproject");
    $template->process($vars);

    $http_response->generate_footer();
}

1;
