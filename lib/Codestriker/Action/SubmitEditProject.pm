###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of editing a project.

package Codestriker::Action::SubmitEditProject;

use strict;

use Codestriker;
use Codestriker::Model::Project;
use Codestriker::Action::ListProjects;
use Codestriker::Action::EditProject;

# If the input is valid, update the appropriate project into the database.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    # Check if this operation is allowed.
    if (Codestriker->projects_disabled()) {
	$http_response->error("This function has been disabled");
    }

    my $query = $http_response->get_query();

    my $project_state = $http_input->get('project_state');

    # Check that the state parameter is valid.
    my $found = 0;
    foreach my $state (@Codestriker::project_states) {
	if ($project_state eq $state) {
	    $found = 1;
	    last;
	}
    }
    if (!$found) {
	$http_response->error("Invalid project state: $project_state");
    }

    # Check if this action is allowed.
    if ($project_state eq "Deleted") {
	$http_response->error("This function has been disabled");
    }

    # Check that the appropriate fields have been filled in.
    my $id = $http_input->get('projectid');
    my $name = $http_input->get('project_name');
    my $description = $http_input->get('project_description');
    my $version = $http_input->get('version');

    my $feedback = "";

    if ($name eq "") {
	$feedback .= "No project name was entered.\n";
    }
    if ($description eq "") {
	$feedback .= "No project description was entered.\n";
    }

    # Try to update the project in the model.
    if ($feedback eq "") {
	my $rc;

	if ($project_state eq "Deleted")
	{
	    $rc =
		Codestriker::Model::Project->delete($id, $version);
	}
	else
	{
	    $rc =
		Codestriker::Model::Project->update($id, $name,	$description,
						    $version, $project_state);
	}

	if ($rc == $Codestriker::INVALID_PROJECT) {
	    $feedback .=
		"Project with name \"$name\" doesn't exist.\n";
	} elsif ($rc == $Codestriker::STALE_VERSION) {
	    $feedback .=
		"Project was modified by another user.\n";
	}
    }

    # If there was a problem, direct control back to the edit project
    # screen, otherwise go to the project list screen.
    if ($feedback ne "") {
	$http_input->{feedback} = $feedback;
    } else {
	$http_input->{feedback} = "Project updated.\n";
    }

    if ($project_state ne "Deleted")
    {
	Codestriker::Action::EditProject->process($http_input,
						  $http_response);
    }
    else
    {
	Codestriker::Action::ListProjects->process($http_input,
						   $http_response);
    }
}

1;
