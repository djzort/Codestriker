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

# Create an appropriate form for creating a new topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    $http_response->generate_header("", "Create new topic", "", "", "", "",
				    "", "", "", 0, 0);

    # Create the hash for the template variables.
    my $vars = {};

    # Retrieve the email, reviewers, cc and repository from the cookie.
    $vars->{'email'} =
	Codestriker::Http::Cookie->get_property($query, 'email');
    $vars->{'reviewers'} =
	Codestriker::Http::Cookie->get_property($query, 'reviewers');
    $vars->{'cc'} =
	Codestriker::Http::Cookie->get_property($query, 'cc');
    $vars->{'repository'} =
	Codestriker::Http::Cookie->get_property($query, 'repository');

    # Indicate if the repository field should be displayed.
    $vars->{'allow_repositories'} = $Codestriker::allow_repositories;

    # Set the default repository.
    if (! (defined $vars->{'repository'}) || $vars->{'repository'} eq "") {
	$vars->{'repository'} = $Codestriker::default_repository;
    }

    my $template = Codestriker::Http::Template->new("createtopic");
    $template->process($vars) || die $template->error();
}

1;
