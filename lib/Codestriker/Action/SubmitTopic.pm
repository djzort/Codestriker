###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of a new topic.

package Codestriker::Action::SubmitTopic;

use strict;

use FileHandle;
use Codestriker::Model::Topic;
use Codestriker::Smtp::SendEmail;
use Codestriker::Http::Render;
use Codestriker::BugDB::BugDBConnectionFactory;
use Codestriker::Repository::RepositoryFactory;
use Codestriker::FileParser::Parser;
use Codestriker::Model::Project;

# If the input is valid, create the appropriate topic into the database.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $topic_title = $http_input->get('topic_title');
    my $topic_description = $http_input->get('topic_description');
    my $reviewers = $http_input->get('reviewers');
    my $email = $http_input->get('email');
    my $cc = $http_input->get('cc');
    my $fh = $http_input->get('fh');
    my $topic_file = $http_input->get('fh_filename');
    my $fh_mime_type = $http_input->get('fh_mime_type');
    my $bug_ids = $http_input->get('bug_ids');
    my $repository_url = $http_input->get('repository');
    my $projectid = $http_input->get('projectid');
    my $start_tag = $http_input->get('start_tag');
    my $end_tag = $http_input->get('end_tag');
    my $module = $http_input->get('module');

    my $feedback = "";
    my $topic_text = "";

    # Indicate whether the topic text needs to be retrieved by the repository
    # object.
    my $retrieve_text_from_rep = 0;
    if ($start_tag ne "" && $end_tag ne "" && $module ne "") {
	$retrieve_text_from_rep = 1;

	# Check if this action is permitted.
	if ($Codestriker::allow_repositories == 0) {
	    $feedback .= "Repository functionality has been disabled.  " .
		"Can't create topic text usings tags.\n";
	}
    }

    if ($topic_title eq "") {
	$feedback .= "No topic title was entered.\n";
    }
    if ($topic_description eq "") {
	$feedback .= "No topic description was entered.\n";
    }
    if ($email eq "") {
	$feedback .= "No email address was entered.\n";
    }
    if (!defined $fh && $retrieve_text_from_rep == 0) {
	$feedback .= "No filename or module/tags were entered.\n";
    }
    if ($reviewers eq "") {
	$feedback .= "No reviewers were entered.\n";
    }
    if ($feedback ne "" && defined $fh) {
	$feedback .= "For security reasons, please re-enter the file name to upload.\n";
    }
    
    $http_response->generate_header("", "Create new topic", $email, $reviewers,
				    $cc, "", "", $repository_url, $projectid,
				    "", 0, 0);

    # Set the error_vars in case of any errorsm that will require forwarding
    # to the create topic screen again.
    my $error_vars = {};
    $error_vars->{'version'} = $Codestriker::VERSION;
    $error_vars->{'feedback'} = $feedback;
    $error_vars->{'email'} = $email;
    $error_vars->{'reviewers'} = $reviewers;
    $error_vars->{'cc'} = $cc;
    $error_vars->{'allow_repositories'} = $Codestriker::allow_repositories;
    $error_vars->{'topic_file'} = $topic_file;
    $error_vars->{'topic_description'} = $topic_description;
    $error_vars->{'topic_title'} = $topic_title;
    $error_vars->{'bug_ids'} = $bug_ids;
    $error_vars->{'default_repository'} = $repository_url;
    $error_vars->{'repositories'} = \@Codestriker::valid_repositories;
    $error_vars->{'start_tag'} = $start_tag;
    $error_vars->{'end_tag'} = $end_tag;
    $error_vars->{'module'} = $module;
    $error_vars->{'maximum_topic_size_lines'} = $Codestriker::maximum_topic_size_lines eq "" ? 
                                          0 : 
                                          $Codestriker::maximum_topic_size_lines;
                                          
    $error_vars->{'suggested_topic_size_lines'} = $Codestriker::suggested_topic_size_lines eq "" ? 
                                          0 : 
                                          $Codestriker::suggested_topic_size_lines;

    # If there is a problem with the input, redirect to the create screen
    # with the message.
    if ($feedback ne "") {
	_forward_create_topic($error_vars, $feedback);
	$http_response->generate_footer();
	return;
    }

    # Set the repository to the default if it is not entered.
    if ($repository_url eq "") {
	$repository_url = $Codestriker::valid_repositories[0];
    }

    # Check if the repository argument is valid.
    my $repository =
	Codestriker::Repository::RepositoryFactory->get($repository_url);

    # For "hysterical" reasons, the topic id is randomly generated.  Seed the
    # generator based on the time and the pid.  Keep searching until we find
    # a free topicid.  In 99% of the time, we will get a new one first time.
    srand(time() ^ ($$ + ($$ << 15)));
    my $topicid;
    do {
	$topicid = int rand(10000000);
    } while (Codestriker::Model::Topic->exists($topicid));

    # If the topic text needs to be retrieved from the repository object,
    # create a temporary file to store the topic text.
    my $temp_topic_filename = "";
    my $temp_error_filename = "";
    if ($retrieve_text_from_rep && defined $repository) {

	# Store the topic text into this temporary file.
	$temp_topic_filename = "topictext.$topicid";
	$temp_error_filename = "errortext.$topicid";
	$fh = new FileHandle "> $temp_topic_filename";
	my $rc = $repository->getDiff($start_tag, $end_tag, $module, $fh,
				      $temp_error_filename);
	$fh->close;

	# Check if the generated diff was too big, and if so, throw an error
	# message on the screen.
	if ($rc == $Codestriker::DIFF_TOO_BIG) {
	    $feedback .= "Generated diff file is too big.\n";
	} elsif ($rc == $Codestriker::UNSUPPORTED_OPERATION) {
	    $feedback .= "Repository \"" . $repository->toString() .
		"\" doesn't support topic text tag retrieval.\n";
	}

	# Open the file again for reading, so that it can be parsed.
	$fh = new FileHandle $temp_topic_filename, "r" if $feedback eq "";
    }

    if ($feedback ne "") {
	# If there was a problem generating the diff file, remove the
	# temporary files, and direct control to the create screen again.
	unlink $temp_topic_filename if $temp_topic_filename ne "";
	unlink $temp_error_filename if $temp_error_filename ne "";
	_forward_create_topic($error_vars, $feedback);
	$http_response->generate_footer();
	return;
    }

    # Try to parse the topic text into its diff chunks.
    my @deltas =
	Codestriker::FileParser::Parser->parse($fh, "text/plain", $repository,
					       $topicid, $topic_file);

    # If the topic text has been uploaded from a file, read from it now.
    if (defined $fh) {
	while (<$fh>) {
	    $topic_text .= $_;
	}
	if ($topic_text eq "") {
	    if ($temp_error_filename ne "" &&
		-f $temp_error_filename) {
		local $/ = undef;
		open(ERROR_FILE, "$temp_error_filename");
		$feedback .= "Problem generating topic text:\n\n";
		$feedback .= <ERROR_FILE>;
		close ERROR_FILE;
	    }
	    else {
		$feedback = "Uploaded file doesn't exist or is empty.\n";
	    }

	    # Remove the temporary files if required, and forward control
	    # back to the create topic page.
	    unlink $temp_topic_filename if $temp_topic_filename ne "";
	    unlink $temp_error_filename if $temp_error_filename ne "";
	    _forward_create_topic($error_vars, $feedback);
	    $http_response->generate_footer();
	    return;
	}
    }

    # Remove the temporary files if required.
    unlink $temp_topic_filename if $temp_topic_filename ne "";
    unlink $temp_error_filename if $temp_error_filename ne "";

    # Remove \r from the topic text.
    $topic_text =~ s/\r//g;

    # Make sure the topic is not too large, count the number of \n
    # in the topic content text.
    my $new_topic_length = 0;
    ++$new_topic_length while ($topic_text =~ /\n/g);
     
    if (defined($Codestriker::maximum_topic_size_lines) && 
        $Codestriker::maximum_topic_size_lines ne "" &&
        $Codestriker::maximum_topic_size_lines < $new_topic_length)
    {        
	$feedback .= "The topic length of $new_topic_length lines is too long. " . 
                     "Topics cannot exceed $Codestriker::maximum_topic_size_lines " . 
                     "lines long. Plesae remove content from topic, or break the topic " .
                     "into several independent topics.\n";
                     
        _forward_create_topic($error_vars, $feedback);
        $http_response->generate_footer();
        return;
    }
    
    # Create the topic in the model.
    my $timestamp = Codestriker->get_timestamp(time);
    Codestriker::Model::Topic->create($topicid, $email, $topic_title,
				      $bug_ids, $reviewers, $cc,
				      $topic_description, $topic_text,
				      $timestamp, $repository, $projectid,
				      \@deltas);

    # Obtain a URL builder object and determine the URL to the topic.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);
    my $topic_url = $url_builder->view_url_extended($topicid, -1, "", "", "",
						    $query->url(), 0);

    # Send an email to the document author and all contributors with the
    # relevant information.  The person who wrote the comment is indicated
    # in the "From" field, and is BCCed the email so they retain a copy.
    my $from = $email;
    my $to = $reviewers;
    my $bcc = $email;
    my $subject = "[REVIEW] Topic \"$topic_title\" created\n";
    my $body =
	"Topic \"$topic_title\" created\n" .
	"Author: $email\n" .
	(($bug_ids ne "") ? "Bug IDs: $bug_ids\n" : "") .
	"Reviewers: $reviewers\n" .
	"URL: $topic_url\n\n" .
	"Description:\n" .
	"$Codestriker::Smtp::SendEmail::EMAIL_HR\n\n" .
	"$topic_description\n";

    # Send the email notification out.
    if (!Codestriker::Smtp::SendEmail->doit(1, $topicid, $from, $to, $cc, $bcc,
					    $subject, $body)) {
	_forward_create_topic($error_vars,
			      "Failed to send topic creation email");
	$http_response->generate_footer();
	return;
    }

    # If Codestriker is linked to a bug database, and this topic is associated
    # with some bugs, update them with an appropriate message.
    if ($bug_ids ne "" && $Codestriker::bug_db ne "") {
	my $bug_db_connection =
	    Codestriker::BugDB::BugDBConnectionFactory->getBugDBConnection();
	$bug_db_connection->get_connection();
	my @ids = split /, /, $bug_ids;
	my $text = "Codestriker topic: $topic_url created.\n" .
	    "Author: $email\n" .
	    "Reviewer(s): $reviewers\n" .
	    "Title: $topic_title\n";
	for (my $i = 0; $i <= $#ids; $i++) {
	    $bug_db_connection->update_bug($ids[$i], $text);
	}
	$bug_db_connection->release_connection();
    }

    # Indicate to the user that the topic has been created and an email has
    # been sent.
    my $vars = {};
    $vars->{'version'} = $Codestriker::VERSION;
    $vars->{'topic_title'} = $topic_title;
    $vars->{'email'} = $email;
    $vars->{'topic_url'} = $topic_url;
    $vars->{'reviewers'} = $reviewers;
    $vars->{'cc'} = (defined $cc) ? $cc : "";

    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [ 0 ], undef);

    my $template = Codestriker::Http::Template->new("submittopic");
    $template->process($vars);

    $http_response->generate_footer();
}

# Direct output to the create topic screen again, with the appropriate feedback
# message.
sub _forward_create_topic($$) {
    my ($vars, $feedback) = @_;

    $feedback =~ s/\n/<BR>/g;
    $vars->{'feedback'} = $feedback;
    my @projects = Codestriker::Model::Project->list();
    $vars->{'projects'} = \@projects;
    
    my $template = Codestriker::Http::Template->new("createtopic");
    $template->process($vars);
}

1;
