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
use Codestriker::Model::File;
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
    my $fn = $http_input->get('fn');
    my $new = $http_input->get('new');
    my $comments = $http_input->get('comments');
    my $email = $http_input->get('email');
    my $cc = $http_input->get('comment_cc');
    my $mode = $http_input->get('mode');
    my $anchor = $http_input->get('a');
    
    # Check that the fields have been filled appropriately.
    if ($comments eq "" || !defined $comments) {
	$http_response->error("No comments were entered");
    }
    if ($email eq "" || !defined $email) {
	$http_response->error("No email address was entered");
    }

    # Create the comment in the database.
    my $timestamp = Codestriker->get_timestamp(time);
    Codestriker::Model::Comment->create($topic, $line, $fn, $new,
					$email, $comments, $timestamp,
					$Codestriker::COMMENT_SUBMITTED);

    # Send an email to the document author and all contributors with the
    # relevant information.  The person who wrote the comment is indicated
    # in the "From" field, and is BCCed the email so they retain a copy.
    my $edit_url = $url_builder->edit_url($fn, $line, $new,
					  $topic, "", "", $query->url());
    my $view_topic_url = $url_builder->view_url($topic, $line, $mode);
    my $view_comments_url = $url_builder->view_comments_url($topic);

    # Retrieve the appropriate topic details.
    my ($document_author, $document_title, $document_bug_ids,
	$document_reviewers, $document_cc, $description,
	$topic_data, $document_creation_time, $document_modified_time,
	$topic_state, $version, $repository);
    my $rc = Codestriker::Model::Topic->read($topic, \$document_author,
					     \$document_title,
					     \$document_bug_ids,
					     \$document_reviewers,
					     \$document_cc,
					     \$description, \$topic_data,
					     \$document_creation_time,
					     \$document_modified_time,
					     \$topic_state,
					     \$version, \$repository);

    if ($rc == $Codestriker::INVALID_TOPIC) {
	# Topic no longer exists, most likely its been deleted.
	$http_response->error("Topic no longer exists.");
    }

    # Retrieve the diff hunk for this file and line number.
    my $delta = Codestriker::Model::File->get_delta($topic, $fn, $line, $new);

    # Retrieve the comment details for this topic.
    my @comments = Codestriker::Model::Comment->read($topic);
    my %contributors = ();
    $contributors{$email} = 1;
    my $cc_recipients = "";
    for (my $i = 0; $i <= $#comments; $i++) {
	if ($comments[$i]{fileline} == $line &&
	    $comments[$i]{filenumber} == $fn &&
	    $comments[$i]{filenew} == $new &&
	    $comments[$i]{author} ne $document_author &&
	    ! exists $contributors{$comments[$i]{author}}) {
	    $contributors{$comments[$i]{author}} = 1;
	    $cc_recipients .= "$comments[$i]{author}, ";
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

    $body .= "File: " . $delta->{filename} . " line $line.\n\n";

    $body .= "Context:\n";
    $body .= "$Codestriker::Smtp::SendEmail::EMAIL_HR\n\n";
    my $email_context = $Codestriker::EMAIL_CONTEXT;
    $body .= Codestriker::Http::Render->get_context($line, $topic,
						    $email_context, 0,
						    $delta->{old_linenumber},
						    $delta->{new_linenumber},
						    $delta->{text}, $new)
	. "\n";
    $body .= "$Codestriker::Smtp::SendEmail::EMAIL_HR\n\n";    
    
    # Now display the comments that have already been submitted.
    for (my $i = $#comments; $i >= 0; $i--) {
	if ($comments[$i]{fileline} == $line &&
	    $comments[$i]{filenumber} == $fn &&
	    $comments[$i]{filenew} == $new) {
	    my $data = $comments[$i]{data};

	    $body .= "$comments[$i]{author} $comments[$i]{date}\n\n$data\n\n";
	    $body .= "$Codestriker::Smtp::SendEmail::EMAIL_HR\n\n";    
	}
    }

    # Send the email notification out.
    if (!Codestriker::Smtp::SendEmail->doit(0, $topic, $from, $to,
					    $cc_recipients, $bcc,
					    $subject, $body)) {
	$http_response->error("Failed to send topic creation email");
    }

    # Display a simple screen indicating that the comment has been registered.
    # Clicking the Close button simply dismisses the edit popup.  Leaving it
    # up will ensure the next editing topic will be handled quickly, as the
    # overhead of bringing up a new window is removed.
    my $reload = $query->param('submit') eq 'Submit+Refresh' ? 1 : 0;
    $http_response->generate_header($topic, "Comment submitted", $email, "",
				    "", "", "", $repository, "", $anchor,
				    $reload, 0);

    my $vars = {};
    $vars->{'version'} = $Codestriker::VERSION;
    $vars->{'view_topic_url'} = $view_topic_url;
    $vars->{'view_comments_url'} = $view_comments_url;
    $vars->{'comment'} = $comments;

    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [ 0 ], undef);

    my $template = Codestriker::Http::Template->new("submitcomment");
    $template->process($vars);

    $http_response->generate_footer();
}

# Given a topic and topic line number, try to determine the line
# number of the new file it corresponds to.  For topic lines which
# were made against '+' lines or unchanged lines, this will give an
# accurate result.  For other situations, the number returned will be
# approximate.  The results are returned in $filename_ref,
# $linenumber_ref and $accurate_ref references.  This is a deprecated method
# which is only used for data migration purposes (within checksetup.pl and
# import.pl).
sub _get_file_linenumber ($$$$$$$$)
{
    my ($type, $topic, $topic_linenumber, $filenumber_ref,
	$filename_ref, $linenumber_ref, $accurate_ref, $new_ref) = @_;

    # Find the appropriate file that $topic_linenumber refers to.
    my (@filename, @revision, @offset, @binary);
    Codestriker::Model::File->get_filetable($topic, \@filename, \@revision,
					    \@offset, \@binary);
    # No filetable.
    return 0 if ($#filename == -1);

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
	    $$filenumber_ref = $index;
	    $$filename_ref = $filename[$index];
	    $$linenumber_ref = 1;
	    $$accurate_ref = 0;
	    $$new_ref = 0;
	    return 1;
	}
    }
    $index--;

    # Couldn't find a matching linenumber.
    if ($index < 0 || $index > $#filename) {
	$$filenumber_ref = -1;
	$$filename_ref = "";
	return 1;
    }

    # Retrieve the diff text corresponding to this file.
    my ($tmp_offset, $tmp_revision, $diff_text);
    Codestriker::Model::File->get($topic, $index, \$tmp_offset,
				  \$tmp_revision, \$diff_text);

    # Go through the patch file until we reach the topic linenumber of
    # interest.
    my $new = 0;
    my $accurate_line = 0;
    my $oldfile_linenumber = 0;
    my $newfile_linenumber = 0;
    my $current_topic_linenumber;
    my @lines = split /\n/, $diff_text;
    for (my $i = 0, $current_topic_linenumber = $offset[$index];
	 $i <= $#lines && $current_topic_linenumber <= $topic_linenumber;
	 $i++, $current_topic_linenumber++) {
	$_ = $lines[$i];
	if (/^\@\@ \-(\d+),\d+ \+(\d+),\d+ \@\@.*$/o) {
	    # Matching diff header, record what the current linenumber is now
	    # in the new file.
	    $oldfile_linenumber = $1 - 1;
	    $newfile_linenumber = $2 - 1;
	    $accurate_line = 0;
	    $new = 0;
	}
	elsif (/^\s.*$/o) {
	    # A line with no change.
	    $oldfile_linenumber++;
	    $newfile_linenumber++;
	    $accurate_line = 1;
	    $new = 1;
	}
	elsif (/^\+.*$/o) {
	    # A line corresponding to the new file.
	    $newfile_linenumber++;
	    $accurate_line = 1;
	    $new = 1;
	}
	elsif (/^\-.*$/o) {
	    # A line corresponding to the old file.
	    $oldfile_linenumber++;
	    $accurate_line = 0;
	    $new = 0;
	}
    }

    if ($current_topic_linenumber >= $topic_linenumber) {
	# The topic linenumber was found.
	$$filenumber_ref = $index;
	$$filename_ref = $filename[$index];
	$$linenumber_ref = $new ? $newfile_linenumber : $oldfile_linenumber;
	$$accurate_ref = $accurate_line;
	$$new_ref = $new;
    }
    else {
	# The topic linenumber was not found.
	$$filenumber_ref = -1;
	$$filename_ref = "";
    }
    return 1;
}

1;
