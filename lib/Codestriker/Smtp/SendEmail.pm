###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Methods for sending an email.

package Codestriker::Smtp::SendEmail;

use Sys::Hostname;
use strict;

use vars qw ( $EMAIL_HR );

# Separator to use in email.
$EMAIL_HR = "--------------------------------------------------------------";

# Send an email with the specified data.  Return false if the mail can't be
# successfully delivered, true otherwise.
sub doit($$$$$$$$$) {
    my ($type, $new, $topicid, $from, $to, $cc, $bcc, $subject, $body) = @_;
    
    open(MAIL, "| $Codestriker::sendmail -t") || return 0;

    print MAIL "From: $from\n";
    print MAIL "To: $to\n";
    print MAIL "Cc: $cc\n" if ($cc ne "");
    print MAIL "Bcc: $bcc\n" if ($bcc ne "");

    # If the message is new, create the appropriate message id, otherwise
    # construct a message which refers to the original message.  This will
    # allow for threading, for those email clients which support it.
    my $message_id = "<Codestriker-" . hostname() . "-${topicid}>";

    if ($new) {
	print MAIL "Message-Id: $message_id\n";
    } else {
	print MAIL "References: $message_id\n";
	print MAIL "In-Reply-To: $message_id\n";
    }

    print MAIL "Subject: $subject\n";

    # Insert a blank line for the body.
    print MAIL "\n";
    print MAIL "$body";
    print MAIL ".\n";
    
    # Check if there were any error messages from sendmail.
    if (! close MAIL) {
	return 0;
    } else {
	return 1;
    }
}

1;
