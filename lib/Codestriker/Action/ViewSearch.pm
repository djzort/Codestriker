###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying the topic search page.

package Codestriker::Action::ViewSearch;

use strict;
use Codestriker::Model::Project;

# Create an appropriate form for topic searching.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check if this action is allowed.
    if ($Codestriker::allow_searchlist == 0) {
	$http_response->error("This function has been disabled");
    }

    $http_response->generate_header("", "Search", "", "", "", "", "", "", "",
				    "", 0, 0);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'version'} = $Codestriker::VERSION;

    # Create the list of valid states that can be searched over.
    my @states = ("Any");
    push @states, @Codestriker::topic_states;
    $vars->{'states'} = \@states;

    # Get the list of valid topics in the system that can be searched over.
    my @projects_db = Codestriker::Model::Project->list();
    my @projects = ();
    my $any_project = {};
    $any_project->{id} = -1;
    $any_project->{name} = "Any";
    push @projects, $any_project;

    foreach my $project (@projects_db) {
	push @projects, $project;
    }
    $vars->{'projects'} = \@projects;

    my $template = Codestriker::Http::Template->new("search");
    $template->process($vars) || die $template->error();
}

1;
