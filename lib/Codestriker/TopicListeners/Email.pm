###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Topic Listeners to do email notification. All email sent from Codestriker
# is sent from this file when an topic event happens.

use strict;
use warnings;

package Codestriker::TopicListeners::Email;

use Codestriker::TopicListeners::TopicListener;
use Net::SMTP;
use Sys::Hostname;

# Separator to use in email.
our $EMAIL_HR = "--------------------------------------------------------------";
# If true, just ignore all email requests.
my $DEVNULL_EMAIL = 0;

our @ISA = ("Codestriker::TopicListeners::TopicListener");

sub new {
    my $type = shift;
    
    # TopicListener is parent class.
    my $self = Codestriker::TopicListeners::TopicListener->new();
    return bless $self, $type;
}

sub topic_create($$) { 
    my ($self, $topic) = @_;
    
    # Send an email to the document author and all contributors with the
    # relevant information.  The person who wrote the comment is indicated
    # in the "From" field, and is BCCed the email so they retain a copy.
    my $from = $topic->{author};
    my $to = $topic->{reviewers};
    my $cc = $topic->{cc};
    my $bcc = $topic->{author};

    $self->_send_topic_email($topic, "Created", 1, $from, $to, $cc, $bcc);

    return '';
}

sub topic_changed($$$) {
    my ($self, $topic_orig, $topic) = @_;

    # Any topic property changes need to be sent to all parties involved
    # for now, including parties which have been removed from the topic.
    # Eventually, email sending can be controlled by per-user preferences,
    # but in any case, in real practice, topic properties should not be
    # changed that often.

    # Record the list of email addresses already handled.
    my %handled_addresses = ();

    # The from (and bcc) is always the current author.
    my $from = $topic->{author};
    my $bcc = $from;
    $handled_addresses{$from} = 1;

    # The to are the current reviewers.
    my $to = $topic->{reviewers};
    foreach my $email (split /, /, $to) {
	$handled_addresses{$email} = 1;
    }

    # The CC consist of the current CC, plus "removed" email addresses handled
    # below.
    my $cc = $topic->{cc};
    foreach my $email (split /, /, $cc) {
	$handled_addresses{$email} = 1;
    }

    # Now add any removed email addresses, and add them to the email's CC.
    my @other_emails = ();
    if (! exists $handled_addresses{$topic_orig->{author}}) {
	push @other_emails, $topic_orig->{author};
    }
    foreach my $email (split /, /, $topic_orig->{reviewers}) {
	if (! exists $handled_addresses{$email}) {
	    push @other_emails, $email;
	}
    }
    foreach my $email (split /, /, $topic_orig->{cc}) {
	if (! exists $handled_addresses{$email}) {
	    push @other_emails, $email;
	}
    }
    my $other_emails = join ', ', @other_emails;
    if (defined $other_emails && $other_emails ne "") {
	$cc .= ", " if $cc ne "";
	$cc .= $other_emails;
    }

    # Send off the email to the revelant parties.
    $self->_send_topic_email($topic, "Modified", 1, $from, $to, $cc, $bcc);
}

sub comment_create($$$) {
    my ($self, $topic, $comment) = @_;
        
    my $query = new CGI;
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);
    
    # Send an email to the document author and all contributors with the
    # relevant information.  The person who wrote the comment is indicated
    # in the "From" field, and is BCCed the email so they retain a copy.
    my $edit_url = $url_builder->edit_url($comment->{filenumber}, 
					  $comment->{fileline}, 
					  $comment->{filenew},
					  $comment->{topicid}, "", "",
					  $query->url());

    # Retrieve the diff hunk for this file and line number.
    my $delta = Codestriker::Model::File->get_delta(
                    $comment->{topicid}, 
                    $comment->{filenumber}, 
		    $comment->{fileline}, 
		    $comment->{filenew});

    # Retrieve the comment details for this topic.
    my @comments = $topic->read_comments();

    my %contributors = ();
    $contributors{$comment->{author}} = 1;
    my @cc_recipients;
    for (my $i = 0; $i <= $#comments; $i++) {
	if ( $comments[$i]{fileline} == $comment->{fileline} &&
	     $comments[$i]{filenumber} == $comment->{filenumber} &&
	     $comments[$i]{filenew} == $comment->{filenew} &&
	     $comments[$i]{author} ne $topic->{author} &&
	     ! exists $contributors{$comments[$i]{author}}) {
	    $contributors{$comments[$i]{author}} = 1;
	    push(@cc_recipients, $comments[$i]{author});
	}
    }
        
    push @cc_recipients, (split ',', $comment->{cc});
       
    my $from = $comment->{author};
    my $to = $topic->{author};
    my $bcc = $comment->{author};
    my $subject = "[REVIEW] Topic \"$topic->{title}\" comment added by $comment->{author}";
    my $body =
	"$comment->{author} added a comment to Topic \"$topic->{title}\".\n\n" .
	"URL: $edit_url\n\n";

    $body .= "File: " . $delta->{filename} . " line $comment->{fileline}.\n\n";

    $body .= "Context:\n$EMAIL_HR\n\n";
    my $email_context = $Codestriker::EMAIL_CONTEXT;
    $body .= Codestriker::Http::Render->get_context($comment->{fileline}, 
						    $email_context, 0,
						    $delta->{old_linenumber},
						    $delta->{new_linenumber},
						    $delta->{text}, 
						    $comment->{filenew})
	. "\n";
    $body .= "$EMAIL_HR\n\n";    
    
    # Now display the comments that have already been submitted.
    for (my $i = $#comments; $i >= 0; $i--) {
	if ($comments[$i]{fileline} == $comment->{fileline} &&
	    $comments[$i]{filenumber} == $comment->{filenumber} &&
	    $comments[$i]{filenew} == $comment->{filenew}) {
	    my $data = $comments[$i]{data};

	    $body .= "$comments[$i]{author} $comments[$i]{date}\n\n$data\n\n";
	    $body .= "$EMAIL_HR\n\n";    
	}
    }

    # Send the email notification out, if it is allowed in the config file.
    if ( $Codestriker::allow_comment_email || $comment->{cc} ne "")
    {
	if (!$self->doit(0, $comment->{topicid}, $from, $to,
			join(',',@cc_recipients), $bcc,
			$subject, $body)) {
	    return "Failed to send topic creation email";
        }
    }
    
    return '';    
}

# This is a private helper function that is used to send topic emails. Topic 
# emails include topic creation, state changes, and deletes.
sub _send_topic_email {
    my ($self, $topic, $event_name, $include_url, $from, $to, $cc, $bcc) = @_;
  
    my $query = new CGI;
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);
    my $topic_url = $url_builder->view_url_extended($topic->{topicid}, -1, 
						    "", "", "",
						    $query->url(), 0);
    
    my $subject = "[REVIEW] Topic \"" . $topic->{title} . "\" $event_name\n";
    my $body =
	"Topic \"$topic->{title}\" $event_name\n" .
	"Author: $topic->{author}\n" .
	(($topic->{bug_ids} ne "") ? "Bug IDs: $topic->{bug_ids}\n" : "") .
	"Reviewers: $topic->{reviewers}\n" .
        (($include_url) ? "URL: $topic_url\n\n" : "") .
	"Description:\n" .
	"$EMAIL_HR\n\n" .
	"$topic->{description}\n";

    # Send the email notification out.
    $self->doit(1, $topic->{topicid}, $from, $to, $cc, $bcc, $subject, $body);
}

sub comment_state_change($$$) {
    my ($self, $topic, $comment, $newstate) = @_;

    # Default version of function that does nothing, and allowed the
    # event to continue.
    
    return '';    
}

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
    $smtp->ok() || die "Couldn't send email $!, " . smtp->message();

    $smtp->quit();
    $smtp->ok() || die "Couldn't send email $!, " . smtp->message();

    return 1;
}

1;
