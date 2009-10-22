###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the creation of a new user account.

package Codestriker::Action::AddNewUser;

use strict;
use Net::SMTP;
use Codestriker::Http::UrlBuilder;
use Codestriker::Model::User;

sub process {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    my $email = $http_input->get('email');

    # Check that the user account doesn't already exist.
    if (Codestriker::Model::User->exists($email)) {
        my $feedback = "User account $email already exists.";
        my $url = $url_builder->create_new_user_url(email => $email,
                                                    feedback => $feedback);
        print $query->redirect(-URI => $url);
        return;
    }

    $http_response->generate_header(topic_title=>"Add Account",
                                    reload=>0, cache=>1);

    # Add the new user to the system.
    Codestriker::Action::AddNewUser->add_new_user($email, 0, $url_builder);

    # Now indicate that the operation has succeeded.
    my $template = Codestriker::Http::Template->new("adduser");
    my $vars = {};
    $template->process($vars);

    $http_response->generate_footer();
}

# Add a new user to the system, and send out a challenge/response
# to the specified email address.  This method assumes the email
# address does not already exist.
sub add_new_user {
    my ($type, $email, $admin, $url_builder) = @_;

    # Add the new user to the system.
    Codestriker::Model::User->create($email, $admin);

    # Set a new challenge for this user.
    my $user = Codestriker::Model::User->new($email);
    my $challenge = $user->create_challenge();

    # Now send them an email so that they can respond to the
    # challenge, and prove they own the specified email address.
    my $magic_url = $url_builder->new_password_url(email => $email,
                                                   challenge => $challenge);
    Codestriker::Action::AddNewUser->_send_email($email,
                                                 "New Codestriker Account",
                                                 <<"END_EMAIL_TEXT"
You have (or someone impersonating you has) requested a Codestriker
account with this email address: $email.  To complete registration,
visit the following link:

$magic_url

If you are not the person who made this request, or you wish to cancel
this request, simply ignore and delete this email.
END_EMAIL_TEXT
);

}

# Send an email to the end-user with new/update account information.
sub _send_email {
    my ($type, $email, $subject, $body) = @_;

    # Make sure $Codestriker::daemon_email_address is defined.
    if (! defined $Codestriker::daemon_email_address ||
        $Codestriker::daemon_email_address eq '') {
        die '$daemon_email_address is not set in codestriker.conf';
    }

    Codestriker->send_email(from => $Codestriker::daemon_email_address,
                            to => $email, subject => $subject,
                            body => $body);
}

1;
