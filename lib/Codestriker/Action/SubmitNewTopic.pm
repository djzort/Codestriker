###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of a new topic.

package Codestriker::Action::SubmitNewTopic;

use strict;

use FileHandle;
use Codestriker::Model::Topic;
use Codestriker::Http::Render;
use Codestriker::Repository::RepositoryFactory;
use Codestriker::FileParser::Parser;
use Codestriker::Model::Project;
use Codestriker::TopicListeners::Manager;

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
	if (scalar(@Codestriker::valid_repositories) == 0) {
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
    if ($retrieve_text_from_rep && defined $fh) {
	$feedback .= "Topic text specified using tags and uploaded file.\n";
	$feedback .= "Please choose one topic text method, and try again.\n";
    }
    
    $http_response->generate_header("", "Create new topic", $email, $reviewers,
				    $cc, "", "", $repository_url, $projectid,
				    "", 0, 0);

    # Set the error_vars in case of any errors that will require forwarding
    # to the create topic screen again.
    my $error_vars = {};
    $error_vars->{'version'} = $Codestriker::VERSION;
    $error_vars->{'feedback'} = $feedback;
    $error_vars->{'email'} = $email;
    $error_vars->{'reviewers'} = $reviewers;
    $error_vars->{'cc'} = $cc;
    $error_vars->{'topic_file'} = $topic_file;
    $error_vars->{'topic_description'} = $topic_description;
    $error_vars->{'topic_title'} = $topic_title;
    $error_vars->{'bug_ids'} = $bug_ids;
    $error_vars->{'default_repository'} = $repository_url;
    $error_vars->{'repositories'} = \@Codestriker::valid_repositories;
    $error_vars->{'start_tag'} = $start_tag;
    $error_vars->{'end_tag'} = $end_tag;
    $error_vars->{'module'} = $module;

    my $repository = undef;
    if (scalar(@Codestriker::valid_repositories)) {
	# Set the repository to the default if it is not entered.
	if ($repository_url eq "") {
	    $repository_url = $Codestriker::valid_repositories[0];
	}

	# Check if the repository argument is valid.
	$repository =
	    Codestriker::Repository::RepositoryFactory->get($repository_url);
	if (! defined $repository) {
	    $feedback .=
		"The repository value \"$repository_url\" is invalid.\n" .
		"Please correct this value in your codestriker.conf file, " .
		"and try again.\n";
	}
    }

    # If there is a problem with the input, redirect to the create screen
    # with the message.
    if ($feedback ne "") {
	if (defined $fh) {
	    $feedback .=
		"For security reasons, please re-enter the " .
		"file name to upload, if required.\n";
	}
	_forward_create_topic($error_vars, $feedback);
	$http_response->generate_footer();
	return;
    }

    my $topicid = Codestriker::Model::Topic::create_new_topicid();        
    
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
	$feedback .=
	    "The topic length of $new_topic_length lines is too long. " . 
	    "Topics cannot exceed $Codestriker::maximum_topic_size_lines " . 
	    "lines long. Please remove content from topic, or break the " .
	    "topic into several independent topics.\n";
                     
        _forward_create_topic($error_vars, $feedback);
        $http_response->generate_footer();
        return;
    }
    
    # Create the topic in the model.
    my $topic = Codestriker::Model::Topic->new($topicid);
    $topic->create($topicid, $email, $topic_title,
		   $bug_ids, $reviewers, $cc,
		   $topic_description, $topic_text,
		   $repository_url, $projectid,
		   \@deltas);
                                                                  
    # tell all of the topic listener classes that a topic has 
    # just been created.
    Codestriker::TopicListeners::Manager::topic_create($topic);
                      
    # Obtain a URL builder object and determine the URL to the topic.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);
    my $topic_url = $url_builder->view_url_extended($topicid, -1, "", "", "",
						    $query->url(), 0);
                                                    
    # Indicate to the user that the topic has been created and an email has
    # been sent.
    my $vars = {};
    $vars->{'topic_title'} = $topic_title;
    $vars->{'email'} = $email;
    $vars->{'topic_url'} = $topic_url;
    $vars->{'reviewers'} = $reviewers;
    $vars->{'cc'} = (defined $cc) ? $cc : "";

    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [ 0 ], undef);

    my $template = Codestriker::Http::Template->new("submitnewtopic");
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
