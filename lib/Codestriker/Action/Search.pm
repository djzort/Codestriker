###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying the topic search page.

package Codestriker::Action::Search;

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
				    "", 0, 1);

    # Obtain a URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Create the hash for the template variables.
    my $vars = {};

    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [ 0 ], undef);
 
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

    if ($Codestriker::db =~ /^DBI:Oracle/i) {
	# Oracle only supports searching over the topic title and filename
	# as the other fields are clobs.
	$vars->{'enable_title'} = 1;
	$vars->{'enable_description'} = 0;
	$vars->{'enable_comment'} = 0;
	$vars->{'enable_body'} = 0;
	$vars->{'enable_filename'} = 1;
    }
    else {
	# All other fields can be searched over.
	$vars->{'enable_title'} = 1;
	$vars->{'enable_description'} = 1;
	$vars->{'enable_comment'} = 1;
	$vars->{'enable_body'} = 1;
	$vars->{'enable_filename'} = 1;
    }

    my $template = Codestriker::Http::Template->new("search");
    $template->process($vars);

    $http_response->generate_footer();
}

1;
