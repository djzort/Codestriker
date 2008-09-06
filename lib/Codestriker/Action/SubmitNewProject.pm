###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of a new project.

package Codestriker::Action::SubmitNewProject;

use strict;

use Codestriker;
use Codestriker::Model::Project;
use Codestriker::Action::ListProjects;
use Codestriker::Action::CreateProject;

# If the input is valid, create the appropriate project into the database.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    # Check if this operation is allowed.
    if (Codestriker->projects_disabled()) {
        $http_response->error("This function has been disabled");
    }

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $project_name = $http_input->get('project_name');
    my $project_description = $http_input->get('project_description');

    my $feedback = "";

    if ($project_name eq "") {
        $feedback .= "No project name was entered.\n";
    }
    if ($project_description eq "") {
        $feedback .= "No project description was entered.\n";
    }

    # Try to create the project in the model.
    if ($feedback eq "") {
        my $rc =
          Codestriker::Model::Project->create($project_name,
                                              $project_description);

        if ($rc == $Codestriker::DUPLICATE_PROJECT_NAME) {
            $feedback .=
              "Project with name \"$project_name\" already exists.\n";
        }
    }

    # If there was a problem, direct control back to the create project
    # screen, otherwise go to the project list screen.
    if ($feedback ne "") {
        $http_input->{feedback} = $feedback;
        Codestriker::Action::CreateProject->process($http_input,
                                                    $http_response);
    } else {
        $http_input->{feedback} = "Project created.\n";
        Codestriker::Action::ListProjects->process($http_input,
                                                   $http_response);
    }
}

1;
