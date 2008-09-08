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

    # Send out an email to the user containing the magic URL so that they
    # can prove they own this email address.
    my $smtp = Net::SMTP->new($Codestriker::mailhost);
    defined $smtp || die "Unable to connect to mail server: $!";

    # Perform SMTP authentication if required.
    if (defined $Codestriker::mailuser && $Codestriker::mailuser ne "" &&
        defined $Codestriker::mailpasswd) {
        eval 'use Authen::SASL';
        die "Unable to load Authen::SASL module: $@\n" if $@;
        $smtp->auth($Codestriker::mailuser, $Codestriker::mailpasswd);
    }

    # Set the from/to addresses.
    $smtp->mail("codestriker");
    $smtp->ok() || die "Couldn't set sender to \"codestriker\": $!, " .
      $smtp->message();
    $smtp->recipient($email);
    $smtp->ok() || die "Couldn't set recipient to \"$email\" $!, " .
      $smtp->message();

    # Set the email text.
    $smtp->data();
    $smtp->datasend("From: codestriker\n");
    $smtp->datasend("To: $email\n");
    $smtp->datasend("Subject: $subject\n");

    # Insert the email body.
    $smtp->datasend("\n");
    $smtp->datasend($body);

    # Now send the email.
    $smtp->dataend();
    $smtp->ok() || die "Couldn't send email $!, " . $smtp->message();
    $smtp->quit();
    $smtp->ok() || die "Couldn't send email $!, " . $smtp->message();
}

1;
