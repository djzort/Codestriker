###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Methods for sending an email.

package Codestriker::Smtp::SendEmail;

use Net::SMTP;
use Sys::Hostname;
use strict;

# If true, just ignore all email requests.
my $DEVNULL_EMAIL = 0;

use vars qw ( $EMAIL_HR );

# Separator to use in email.
$EMAIL_HR = "--------------------------------------------------------------";

# Send an email with the specified data.  Return false if the mail can't be
# successfully delivered, true otherwise.
sub doit($$$$$$$$$) {
    my ($type, $new, $topicid, $from, $to, $cc, $bcc, $subject, $body) = @_;

    return 1 if ($DEVNULL_EMAIL);
    
    my $smtp = Net::SMTP->new($Codestriker::mailhost);
    defined $smtp || die "Unable to connect to mail server: $!";

    $smtp->mail($from);
    $smtp->ok() || die "Couldn't set sender to \"$from\" $!, " .
	$smtp->message();

    # $to has to be defined.
    my $recipients = $to;
    $recipients .= ", $cc" if $cc ne "";
    $recipients .= ", $bcc" if $bcc ne "";
    my @receiver = split /, /, $recipients;
    for (my $i = 0; $i <= $#receiver; $i++) {
	$smtp->recipient($receiver[$i]);
	$smtp->ok() || die "Couldn't send email to \"$receiver[$i]\" $!, " .
	    $smtp->message();
    }

    $smtp->data();
    $smtp->datasend("From: $from\n");
    $smtp->datasend("To: $to\n");
    $smtp->datasend("Cc: $cc\n") if $cc ne "";

    # If the message is new, create the appropriate message id, otherwise
    # construct a message which refers to the original message.  This will
    # allow for threading, for those email clients which support it.
    my $message_id = "<Codestriker-" . hostname() . "-${topicid}>";

    if ($new) {
	$smtp->datasend("Message-Id: $message_id\n");
    } else {
	$smtp->datasend("References: $message_id\n");
	$smtp->datasend("In-Reply-To: $message_id\n");
    }

    $smtp->datasend("Subject: $subject\n");

    # Insert a blank line for the body.
    $smtp->datasend("\n");
    $smtp->datasend($body);
    $smtp->dataend();
    $smtp->ok() || die "Couldn't send email $!, " . $smtp->message();

    $smtp->quit();
    $smtp->ok() || die "Couldn't send email $!, " . $smtp->message();

    return 1;
}

1;
