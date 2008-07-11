###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# TestDirector connection class, for appending comments to a bug report.

package Codestriker::BugDB::TestDirectorConnection;

use strict;

# Optional dependency for people who don't use this module.
eval("use Win32::OLE;");

# Static method for building a database connection.
sub get_connection($) {
    my ($type) = @_;

    # Return a connection with Test Director via the TD Object.
    my $self = {};
    eval 'use Win32::OLE';
    die "Unable to load Win32::OLE module: $@\n" if $@;
    my $conn = Win32::OLE->new('TDapiole80.TDconnection');

    if (!$conn) {
	die "Cannot start TestDirector object";
    }

    # Connect to specified server. 
    $conn->InitConnectionEx($Codestriker::testdirector_url);

    # Connect to specified project.
    $conn->Login($Codestriker::testdirector_user_id,
		 $Codestriker::testdirector_password); 
    $conn->Connect($Codestriker::testdirector_domain,
		   $Codestriker::testdirector_project); 

    $self->{dbh} = $conn;
    bless $self, $type;
}

# Method for releasing a Test Director connection.
sub release_connection($) {
    my ($self) = @_;
    
    # Close the TD connection. 
    # Disconnect the project and release the server.
    $self->{dbh}->Disconnect();
    $self->{dbh}->Logout();
    $self->{dbh}->ReleaseConnection();
}

# Retrieve the specified bug record.
sub _retrieve_bug_record {
    my ($self, $bugid) = @_;

    if (! defined $self->{dbh}->bugfactory) {
	die "Unable to retrieve bug factory object";
    }

    return $self->{dbh}->bugfactory->item($bugid);
}

# Return true if the specified bugid exists in the bug database,
# false otherwise.
sub bugid_exists($$) {
    my ($self, $bugid) = @_;
    
    my $bug = $self->_retrieve_bug_record($bugid);
    return defined $bug;
}

# Method for updating the bug with information that a code review has been
# created/closed/committed/deleted against this bug.
sub update_bug($$$$$) {
    my ($self, $bugid, $comment, $topic_url, $topic_state) = @_;

    # Now get the bug out of Test Director.
    my $bug = $self->_retrieve_bug_record($bugid);

    # Test director stores comments as html so convert the comment to html.
    my $parsed_comment = $comment;
    $parsed_comment =~ s/\n/<BR>/g;
    
    my $full_comment = "";
    $full_comment .= "\n<HTML><BODY>\n";
    $full_comment .= "<font color=\"\#000080\">";
    $full_comment .= "<b>Code Review, &nbsp;";
    $full_comment .= localtime;
    $full_comment .= ":</b></font><BR>";
    $full_comment .= $parsed_comment;
    $full_comment .= "</BODY></HTML>\n";

    if (defined $bug->Attachments) {
        if( $topic_state eq "Deleted" ) {
            $self->_update_bug_delete( $bug->Attachments, $topic_url );
        } else {
            my $attach = $bug->Attachments->AddItem([$topic_url,
						     "TDATT_INTERNET",
						     $full_comment]);
            $attach->post();
        }
    }
    else
    {
        $$bug{"BG_DEV_COMMENTS"} .= $full_comment;
        $bug->post();
    }
}

# Method for updating the bug with information that a code review has been
# deleted against this bug.
sub _update_bug_delete($$$) {
    my ($self, $attachments, $topic_url) = @_;

    if( $attachments ) {
	my $attachment_list = $attachments->NewList("");

	my $attach_counter = 1;
	while ( $attach_counter <= $attachment_list->Count ) {
	    my $attachment = $attachment_list->Item($attach_counter);

	    if( $attachment->Name eq $topic_url ) {
	        # Remove the attachment for the deleted topic
		$attachments->RemoveItem($attachment->ID);
	    }
	    $attach_counter++;
	}
    }
}


1;
