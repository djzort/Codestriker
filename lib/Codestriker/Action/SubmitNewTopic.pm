###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of a new topic.

package Codestriker::Action::SubmitNewTopic;

use strict;

use File::Temp qw/ tempfile /;
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
    my $repository_name = $http_input->get('repository');
    my $projectid = $http_input->get('projectid');
    my $project_name = $http_input->get('project_name');
    my $start_tag = $http_input->get('start_tag');
    my $end_tag = $http_input->get('end_tag');
    my $module = $http_input->get('module');
    my $obsoletes = $http_input->get('obsoletes');
    my $default_to_head = $http_input->get('default_to_head');

    my $feedback = "";
    my $topic_text = "";

    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Indicate whether the topic text needs to be retrieved by the repository
    # object.
    my $retrieve_text_from_rep = 0;
    if (($start_tag ne "" || $end_tag ne "") && $module ne "") {
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

    $http_response->generate_header(topic_title=>"Create New Topic",
				    email=>$email, reviewers=>$reviewers,
				    cc=>$cc, repository=>$repository_name,
				    projectid=>$projectid,
				    reload=>0, cache=>0);

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
    $error_vars->{'default_repository'} = $repository_name;
    $error_vars->{'repositories'} = \@Codestriker::valid_repository_names;
    $error_vars->{'start_tag'} = $start_tag;
    $error_vars->{'end_tag'} = $end_tag;
    $error_vars->{'module'} = $module;
    $error_vars->{'obsoletes'} = $obsoletes;
    $error_vars->{'default_to_head'} = $default_to_head;
    $error_vars->{'default_projectid'} = $projectid;

    my $repository = undef;
    my $repository_url = undef;
    if (scalar(@Codestriker::valid_repositories)) {
	# Set the repository to the default if it is not entered.
	if ($repository_name eq "" || scalar(@Codestriker::valid_repository_names) == 1) {
	    $repository_name = $Codestriker::valid_repository_names[0];
	}

	# Check if the repository argument is in fact a configured
        # repository.
        $repository_url = $Codestriker::repository_url_map->{$repository_name};

        if (defined $repository_url) {
	    $repository =
		Codestriker::Repository::RepositoryFactory->get($repository_url);
        }

	if (! defined $repository) {
	    $feedback .=
		"The repository value set for \"$repository_name\" is invalid.\n" .
		"Please correct this value in your codestriker.conf file, " .
		"and try again.\n";
	}
    }

    # Set the projectid to the first (default) if it is invalid.
    my @projects = Codestriker::Model::Project->list();
    my $found_project = 0;
    foreach my $project (@projects) {
        if ((defined $projectid && $project->{id} == $projectid) ||
	    (defined $project_name && $project->{name} eq $project_name)) {
	    $projectid = $project->{id};
            $found_project = 1;
            last;
        }
    }
    if ($found_project == 0) {
        $projectid = $projects[0]->{id};
    }

    # Make sure all the conditions from the topic listeners are satisified.
    $feedback .= Codestriker::TopicListeners::Manager::topic_pre_create
	($email, $topic_title, $topic_description,
	 $bug_ids, $reviewers, $cc,
	 $repository_url, $projectid);

    # If there is a problem with the input, redirect to the create screen
    # with the message.
    if ($feedback ne "") {
	if (defined $fh) {
	    $feedback .=
		"For security reasons, please re-enter the " .
		"file name to upload, if required.\n";
	}
	_forward_create_topic($error_vars, $feedback, $url_builder);
	$http_response->generate_footer();
	return;
    }

    my $topicid = Codestriker::Model::Topic::create_new_topicid();        
    
    # If the topic text needs to be retrieved from the repository object,
    # create a temporary file to store the topic text.
    my $temp_topic_fh;
    my $temp_error_fh;

    if ($retrieve_text_from_rep && defined $repository) {
	# Store the topic text into temporary files.
	if (defined $Codestriker::tmpdir && $Codestriker::tmpdir ne "") {
	    $temp_topic_fh = tempfile(DIR => $Codestriker::tmpdir);
	    $temp_error_fh = tempfile(DIR => $Codestriker::tmpdir);
	}
	else {
	    $temp_topic_fh = tempfile();
	    $temp_error_fh = tempfile();
	}
#	binmode $temp_topic_fh, ':utf8';
#	binmode $temp_error_fh, ':utf8';
	
	my $rc = $repository->getDiff($start_tag, $end_tag, $module,
				      $temp_topic_fh, $temp_error_fh,
				      $default_to_head);

	# Make sure the data has been flushed to disk.
	$temp_topic_fh->flush;
	$temp_error_fh->flush;

	# Check if the generated diff was too big, and if so, throw an error
	# message on the screen.
	if ($rc == $Codestriker::DIFF_TOO_BIG) {
	    $feedback .= "Generated diff file is too big.\n";
	} elsif ($rc == $Codestriker::UNSUPPORTED_OPERATION) {
	    $feedback .= "Repository \"" . $repository_name .
		"\" does not support tag retrieval, you have to use the text file upload.\n";
	} elsif ($rc != $Codestriker::OK) {
	    $feedback .= "Unexpected error $rc retrieving diff text.\n";
	}

	# Seek to the beginning of the temporary file so it can be parsed.
	seek($temp_topic_fh, 0, 0);
	
	# Set $fh to this file reference which contains the topic data.
	$fh = $temp_topic_fh;
    }

    my @deltas = ();
    if ($feedback eq "") {
	# Try to parse the topic text into its diff chunks.
	@deltas =
	    Codestriker::FileParser::Parser->parse($fh, "text/plain", $repository,
						   $topicid, $topic_file);
	if ($#deltas == -1) {
	    # Nothing in the file, report an error.
	    $feedback .= "Reviewable text in topic is empty.\n";
	}
    }

    if ($feedback ne "") {
	# If there was a problem generating the diff file, remove the
	# temporary files, and direct control to the create screen again.
	$temp_topic_fh->close if defined $temp_topic_fh;
	$temp_error_fh->close if defined $temp_error_fh;
	_forward_create_topic($error_vars, $feedback, $url_builder);
	$http_response->generate_footer();
	return;
    }

    # If the topic text has been uploaded from a file, read from it now.
    if (defined $fh) {
	while (<$fh>) {
	    $topic_text .= $_;
	}
	if ($topic_text eq "") {
	    if (defined $temp_error_fh) {
		seek($temp_error_fh, 0, 0);
		$feedback .= "Problem generating topic text:\n\n";
		my $buf = "";
		while (read $temp_error_fh, $buf, 16384) {
		    $feedback .= $buf;
		}
	    }
	    else {
		$feedback = "Uploaded file doesn't exist or is empty.\n";
	    }

	    # Remove the temporary files if required, and forward control
	    # back to the create topic page.
	    $temp_topic_fh->close if defined $temp_topic_fh;
	    $temp_error_fh->close if defined $temp_error_fh;
	    _forward_create_topic($error_vars, $feedback, $url_builder);
	    $http_response->generate_footer();
	    return;
	}
    }

    # Remove the temporary files if required.
    $temp_topic_fh->close if defined $temp_topic_fh;
    $temp_error_fh->close if defined $temp_error_fh;

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
                     
        _forward_create_topic($error_vars, $feedback, $url_builder);
        $http_response->generate_footer();
        return;
    }

    # Make sure the specified topicids to be obsoleted are in fact valid.
    if (defined $obsoletes && $obsoletes ne '') {
	my @data = split ',', $obsoletes;
	for (my $i = 0; $i <= $#data; $i+=2) {
	    my $id = $data[$i];
	    my $version = $data[$i+1];

	    if (! Codestriker::Model::Topic::exists($id)) {
		$feedback .= "Obsoleted topics specified do not exist.\n";
		_forward_create_topic($error_vars, $feedback, $url_builder);
		$http_response->generate_footer();
		return;
	    }
	}
    }

    # Create the topic in the model.
    my $topic = Codestriker::Model::Topic->new($topicid);
    $topic->create($topicid, $email, $topic_title,
		   $bug_ids, $reviewers, $cc,
		   $topic_description, $topic_text,
		   $start_tag, $end_tag, $module,
		   $repository_url, $projectid,
		   \@deltas, $obsoletes);
                                                                  
    # Obsolete any required topics.
    if (defined $obsoletes && $obsoletes ne '') {
	my @data = split ',', $obsoletes;
	for (my $i = 0; $i <= $#data; $i+=2) {
	    my $id = $data[$i];
	    my $version = $data[$i+1];
	    Codestriker::Action::SubmitEditTopicsState
		->update_state($id, $version, 'Obsoleted', $email);
	}
    }
    
    # Tell all of the topic listener classes that a topic has 
    # just been created.
    $feedback = Codestriker::TopicListeners::Manager::topic_create($topic);
                      
    # Obtain a URL builder object and determine the URL to the topic.
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
    $vars->{'feedback'} = $feedback;

    my $template = Codestriker::Http::Template->new("submitnewtopic");
    $template->process($vars);

    $http_response->generate_footer();
}

# Direct output to the create topic screen again, with the appropriate feedback
# message.
sub _forward_create_topic($$$) {
    my ($vars, $feedback, $url_builder) = @_;

    $feedback =~ s/\n/<BR>/g;
    $vars->{'feedback'} = $feedback;
    my @projects = Codestriker::Model::Project->list();
    $vars->{'projects'} = \@projects;
    Codestriker::Action::CreateTopic->
	set_obsoleted_topics_parameter($vars, $url_builder);
    
    my $template = Codestriker::Http::Template->new("createtopic");
    $template->process($vars);
}

1;
