###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling a reset password action.

package Codestriker::Action::ResetPassword;

use strict;
use Net::SMTP;
use Codestriker::Http::UrlBuilder;
use Codestriker::Model::User;
use Codestriker::Action::AddNewUser;

sub process {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    my $email = $http_input->get('email');

    # Check that the user account exists.
    if (!Codestriker::Model::User->exists($email)) {
        my $feedback = "Unknown user $email specified.";
        my $login_url = $url_builder->login(email => $email,
                                            feedback => $feedback);
        print $query->redirect(-URI => $login_url);
        return;
    }

    $http_response->generate_header(topic_title=>"Reset Password",
                                    reload=>0, cache=>1);

    # Create a new challenge for this user.
    my $user = Codestriker::Model::User->new($email);
    my $challenge = $user->create_challenge();

    # Now send out an email to the user with the magic URL so that they
    # can prove they own this email address.
    my $magic_url = $url_builder->new_password_url(email => $email,
                                                   challenge => $challenge);
    Codestriker::Action::AddNewUser->_send_email($email,
                                                 "Reset Password for Codestriker Account",
                                                 <<"END_EMAIL_TEXT"
You have (or someone impersonating you has) requested to change your
Codestriker password. To complete the change, visit the following link:

$magic_url

If you are not the person who made this request, or you wish to cancel
this request, simply ignore and delete this email.
END_EMAIL_TEXT
);

    # Show the post reset-password screen.
    my $template = Codestriker::Http::Template->new("resetpassword");
    my $vars = {};
    $template->process($vars);

    $http_response->generate_footer();
}

1;
