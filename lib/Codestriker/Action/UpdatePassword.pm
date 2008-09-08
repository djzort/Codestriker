###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for updating the password for a user account.

package Codestriker::Action::UpdatePassword;

use strict;
use Codestriker::Http::UrlBuilder;
use Codestriker::Model::User;

# Try to update the user's password assuming the challenge/response
# is correct, then redirect to the login screen with the appropriate
# feedback.
sub process {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    my $email = $http_input->get('email');
    my $challenge = $http_input->get('challenge');
    my $password = $http_input->get('password');

    my $feedback = "";

    # Check if the account for this email address is valid.
    if (!Codestriker::Model::User->exists($email)) {
        $feedback = "Unknown user $email specified.";
    } else {
        my $user = Codestriker::Model::User->new($email);

        # Check that the challenge specified is correct.
        if ($user->{challenge} ne $challenge) {
            $feedback = "Challenge specified is incorrect.  " .
              "Your password has not been changed.";
        } else {
            $user->update_password($password);
            $feedback = "Password has been updated.";
        }
    }

    # Redirect to the login screen with the appropriate feedback.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);
    my $url = $url_builder->login_url(feedback => $feedback);
    print $query->redirect(-URI => $url);
}

1;
