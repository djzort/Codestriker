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
				    "", "", "", 0, 1);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'error_message'} = "";
    $vars->{'topic_text'} = "";
    $vars->{'topic_file'} = "";
    $vars->{'topic_description'} = "";
    $vars->{'topic_title'} = "";
    $vars->{'bug_ids'} = "";
    $vars->{'feedback'} = $http_input->get('feedback');

    # Retrieve the email, reviewers, cc and repository from the cookie.
    $vars->{'email'} =
	Codestriker::Http::Cookie->get_property($query, 'email');
    $vars->{'reviewers'} =
	Codestriker::Http::Cookie->get_property($query, 'reviewers');
    $vars->{'cc'} =
	Codestriker::Http::Cookie->get_property($query, 'cc');
    $vars->{'default_repository'} = 
	Codestriker::Http::Cookie->get_property($query, 'repository');

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

    my $template = Codestriker::Http::Template->new("createtopic");
    $template->process($vars) || die $template->error();
}

1;
