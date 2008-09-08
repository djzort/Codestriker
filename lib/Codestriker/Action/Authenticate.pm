###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for authenticating a user.

package Codestriker::Action::Authenticate;

use strict;
use Codestriker::Http::UrlBuilder;
use Codestriker::Model::User;

sub process {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    my $email = $http_input->get('email');
    my $password = $http_input->get('password');
    my $redirect = $http_input->get('redirect');

    my $feedback = "";

    # Check if the account for this email address is valid.
    my $user;
    if (!Codestriker::Model::User->exists($email)) {
        $feedback = "The username or password you entered is not valid.";
    } else {
        $user = Codestriker::Model::User->new($email);

        # Check that the password entered is correct.
        if (! $user->check_password($password)) {
            $feedback = "The username or password you entered is not valid.";
        }
    }

    # If there is feedback, redirect to the login screen.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);
    if ($feedback ne "") {
        my $url = $url_builder->login_url(feedback => $feedback);
        print $query->redirect(-URI => $url);
    } else {
        # Redirect to the specified URL, if present, otherwise go to the default
        # URL.  Get the current cookie, and set the email and password hash
        # into it.
        my %cookie_hash = Codestriker::Http::Cookie->get($query);
        $cookie_hash{email} = $user->{email};
        $cookie_hash{password_hash} = $user->{password_hash};
        my $cookie = Codestriker::Http::Cookie->make($query, \%cookie_hash);

        if (defined $redirect && $redirect ne "") {
            print $query->redirect(-cookie => $cookie,
                                   -location => $redirect);
        } else {
            print $query->redirect(-cookie => $cookie,
                                   -location => $query->url());
        }
    }
}

1;
