###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of a new comment.

package Codestriker::Action::SubmitComment;

use strict;

use Codestriker::Model::Comment;
use Codestriker::Smtp::SendEmail;

# If the input is valid, create the appropriate topic into the database.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    # Obtain a new URL builder object.
    my $query = $http_response->get_query();
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Check that the appropriate fields have been filled in.
    my $topic = $http_input->get('topic');
    my $line = $http_input->get('line');
    my $comments = $http_input->get('comments');
    my $email = $http_input->get('email');
    my $cc = $http_input->get('cc');
    my $mode = $http_input->get('mode');
    
    # Check that the fields have been filled appropriately.
    if ($comments eq "" || !defined $comments) {
	$http_response->error("No comments were entered");
    }
    if ($email eq "" || !defined $email) {
	$http_response->error("No email address was entered");
    }

    # Create the comment in the database.
    my $timestamp = Codestriker->get_timestamp(time);
    Codestriker::Model::Comment->create($topic, $line, $email, $comments,
					$timestamp);

    # Send an email to the document author and all contributors with the
    # relevant information.  The person who wrote the comment is indicated
    # in the "From" field, and is BCCed the email so they retain a copy.
    my $edit_url = $url_builder->edit_url($line, $topic, "", $query->url());

    # Retrieve the appropriate topic details.
    my ($document_author, $document_title, $document_bug_ids,
	$document_reviewers, $document_cc, $description,
	$topic_data, $document_creation_time, $document_modified_time,
	$topic_state, $version);
    Codestriker::Model::Topic->read($topic, \$document_author,
				    \$document_title, \$document_bug_ids,
				    \$document_reviewers, \$document_cc,
				    \$description, \$topic_data,
				    \$document_creation_time,
				    \$document_modified_time, \$topic_state,
				    \$version);

    # Retrieve the comment details for this topic.
    my (@comment_linenumber, @comment_author, @comment_data, @comment_date,
	%comment_exists);
    Codestriker::Model::Comment->read($topic, \@comment_linenumber,
				      \@comment_data, \@comment_author,
				      \@comment_date, \%comment_exists);
    my %contributors = ();
    $contributors{$email} = 1;
    my $cc_recipients = "";
    for (my $i = 0; $i <= $#comment_linenumber; $i++) {
	if ($comment_linenumber[$i] == $line &&
	    $comment_author[$i] ne $document_author &&
	    ! exists $contributors{$comment_author[$i]}) {
	    $contributors{$comment_author[$i]} = 1;
	    $cc_recipients .= "$comment_author[$i], ";
	}
    }
    
    # Remove the last space and comma character.
    if ($cc_recipients ne "") {
	substr($cc_recipients, -2) = "";
    }

    # Add the $cc recipients if any were specified.
    if ($cc ne "")
    {
	if ($cc_recipients ne "")
	{
	    $cc_recipients .= ", " .
		Codestriker::Http::Input->make_canonical_email_list($cc);
	}
	else
	{
	    $cc_recipients =
		Codestriker::Http::Input->make_canonical_email_list($cc);
	}
    }

    my $from = $email;
    my $to = $document_author;
    my $bcc = $email;
    my $subject = "[REVIEW] Topic \"$document_title\" comment added by $email";
    my $body =
	"$email added a comment to Topic \"$document_title\".\n\n" .
	"URL: $edit_url\n\n";

    # Try to determine what file and line number this comment refers to.
    my $filename = "";
    my $file_linenumber = 0;
    my $accurate = 0;
    _get_file_linenumber($topic, $line, \$filename, \$file_linenumber,
			 \$accurate);
    if ($filename ne "") {
	if ($file_linenumber > 0) {
	    $body .= "File: $filename" . ($accurate ? "" : " around") .
		" line $file_linenumber.\n\n";
	}
	else {
	    $body .= "File: $filename\n\n";
	}
    }

    $body .= "Context:\n";
    $body .= "$Codestriker::Smtp::SendEmail::EMAIL_HR\n\n";
    my @document = split /\n/, $topic_data;
    my $email_context = $Codestriker::EMAIL_CONTEXT;
    $body .= Codestriker::Http::Render->get_context($line, $topic,
						    $email_context, 0,
						    \@document) . "\n";
    $body .= "$Codestriker::Smtp::SendEmail::EMAIL_HR\n\n";    
    
    # Now display the comments that have already been submitted.
    for (my $i = $#comment_linenumber; $i >= 0; $i--) {
	if ($comment_linenumber[$i] == $line) {
	    my $data = $comment_data[$i];

	    $body .= "$comment_author[$i] $comment_date[$i]\n\n$data\n\n";
	    $body .= "$Codestriker::Smtp::SendEmail::EMAIL_HR\n\n";    
	}
    }

    # Send the email notification out.
    if (!Codestriker::Smtp::SendEmail->doit($from, $to, $cc_recipients, $bcc,
					    $subject, $body)) {
	$http_response->error("Failed to send topic creation email");
    }
    
    # Redirect the browser to view the topic back at the same line number where
    # they were adding comments to.
    my $redirect_url =
	$url_builder->view_url_extended($topic, $line, $mode, "", $email, "");
    print $query->redirect(-URI=>$redirect_url);
    return;
}

# Given a topic and topic line number, try to determine the line
# number of the new file it corresponds to.  For topic lines which
# were made against '+' lines or unchanged lins, this will give an
# accurate result.  For other situations, the number returned will be
# approximate.  The results are returned in $filename_ref,
# $linenumber_ref and $accurate_ref references.
sub _get_file_linenumber ($$$$$)
{
    my ($topic, $topic_linenumber,
	$filename_ref, $linenumber_ref, $accurate_ref) = @_;
    
    # Find the appropriate file that $topic_linenumber refers to.
    my (@filename, @revision, @offset);
    Codestriker::Model::File->get_filetable($topic, \@filename, \@revision,
					    \@offset);
    my $diff_limit = -1;
    my $index;
    for ($index = 0; $index <= $#filename; $index++) {
	last if ($offset[$index] > $topic_linenumber);
    }

    # Check if the comment was made against a diff header.
    if ($index <= $#offset) {
	my $diff_header_size;
	if ($revision[$index] eq $Codestriker::ADDED_REVISION ||
	    $revision[$index] eq $Codestriker::REMOVED_REVISION) {
	    # Added or removed file.
	    $diff_header_size = 6;
	}
	elsif ($revision[$index] eq $Codestriker::PATCH_REVISION) {
	    # Patch file
	    $diff_header_size = 3;
	}
	else {
	    # Normal CVS diff header.
	    $diff_header_size = 7;
	}

	if ( ($topic_linenumber >=
	      $offset[$index] - $diff_header_size) &&
	     ($topic_linenumber <= $offset[$index]) ) {
	    $$filename_ref = $filename[$index];
	    $$linenumber_ref = -1;
	    $$accurate_ref = 0;
	    return;
	}
    }
    $index--;

    # Couldn't find a matching linenumber.
    if ($index < 0 || $index > $#filename) {
	$$filename_ref = "";
	return;
    }

    # Retrieve the diff text corresponding to this file.
    my ($tmp_offset, $tmp_revision, $diff_text);
    Codestriker::Model::File->get($topic, $filename[$index], \$tmp_offset,
				  \$tmp_revision, \$diff_text);

    # Go through the patch file until we reach the topic linenumber of
    # interest.
    my $accurate_line = 0;
    my $newfile_linenumber = 0;
    my $current_topic_linenumber;
    my @lines = split /\n/, $diff_text;
    for (my $i = 0, $current_topic_linenumber = $offset[$index];
	 $i <= $#lines && $current_topic_linenumber <= $topic_linenumber;
	 $i++, $current_topic_linenumber++) {
	$_ = $lines[$i];
	if (/^\@\@ \-\d+,\d+ \+(\d+),\d+ \@\@.*$/o) {
	    # Matching diff header, record what the current linenumber is now
	    # in the new file.
	    $newfile_linenumber = $1 - 1;
	    $accurate_line = 0;
	}
	elsif (/^\s.*$/o) {
	    # A line with no change.
	    $newfile_linenumber++;
	    $accurate_line = 1;
	}
	elsif (/^\+.*$/o) {
	    # A line corresponding to the new file.
	    $newfile_linenumber++;
	    $accurate_line = 1;
	}
	elsif (/^\-.*$/o) {
	    # A line corresponding to the old file.
	    $accurate_line = 0;
	}
    }

    if ($current_topic_linenumber >= $topic_linenumber) {
	# The topic linenumber was found.
	$$filename_ref = $filename[$index];
	$$linenumber_ref = $newfile_linenumber;
	$$accurate_ref = $accurate_line;
    }
    else {
	# The topic linenumber was not found.
	$$filename_ref = "";
    }
    return;
}

1;
