###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the viewing of a topic.

package Codestriker::Action::ViewTopic;

use strict;

use Codestriker::Model::Topic;
use Codestriker::Model::Comment;
use Codestriker::Http::UrlBuilder;
use Codestriker::Http::Render;

# If the input is valid, display the topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    my $topic = $http_input->get('topic');
    my $mode = $http_input->get('mode');
    my $tabwidth = $http_input->get('tabwidth');
    my $email = $http_input->get('email');
    my $feedback = $http_input->get('feedback');

    # Retrieve the appropriate topic details.
    my ($document_author, $document_title, $document_bug_ids,
	$document_reviewers, $document_cc, $description,
	$topic_data, $document_creation_time, $document_modified_time,
	$topic_state, $version, $repository_url);
    my $rc = Codestriker::Model::Topic->read($topic, \$document_author,
					     \$document_title,
					     \$document_bug_ids,
					     \$document_reviewers,
					     \$document_cc,
					     \$description, \$topic_data,
					     \$document_creation_time,
					     \$document_modified_time,
					     \$topic_state,
					     \$version, \$repository_url);

    if ($rc == $Codestriker::INVALID_TOPIC) {
	# Topic no longer exists, most likely its been deleted.
	$http_response->error("Topic no longer exists.");
    }

    # Retrieve the changed files which are a part of this review.
    my (@filenames, @revisions, @offsets, @binary);
    Codestriker::Model::File->get_filetable($topic, \@filenames,
					    \@revisions, \@offsets, \@binary);

    # If there are no files associated with this topic, there is no point
    # showing a coloured mode - drop back to the text view.
    if ($#filenames == -1) {
	$mode = $Codestriker::NORMAL_MODE;
    }

    # Retrieve line-by-line versions of the data and description.
    my @document_description = split /\n/, $description;
    my @document = split /\n/, $topic_data;

    # Retrieve the comment details for this topic.
    my @comments = Codestriker::Model::Comment->read($topic);

    $http_response->generate_header($topic, $document_title, $email,
				    "", "", $mode, $tabwidth, $repository_url,
				    "", 0, 1);

    # Retrieve the repository object, if repository functionality is enabled.
    my $repository;
    my $repository_root = "";
    if ($Codestriker::allow_repositories) {
	$repository =
	    Codestriker::Repository::RepositoryFactory->get($repository_url);
	$repository_root = defined $repository ? $repository->getRoot() : "";
    } else {
	# Indicate not to activate any repository-related links.
	$repository_url = "";
    }

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'feedback'} = $feedback;
    $vars->{'topicid'} = $topic;

    # Create the necessary template variables for generating the heading part
    # of the view topic display.

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Obtains the "Create a new topic", "Search" and "Open topics" URLs.
    my $view_comments_url = $url_builder->view_comments_url($topic);
    $vars->{'create_topic_url'} = $url_builder->create_topic_url();
    $vars->{'search_url'} = $url_builder->search_url();
    my @topic_states = (0);
    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", \@topic_states);
    $vars->{'view_comments_url'} = $view_comments_url;

    # Display the "update" message if the topic state has been changed.
    $vars->{'updated'} = $http_input->get('updated');
    $vars->{'rc_ok'} = $Codestriker::OK;
    $vars->{'rc_stale_version'} = $Codestriker::STALE_VERSION;
    $vars->{'rc_invalid_topic'} = $Codestriker::INVALID_TOPIC;

    # Indicate if the "delete" button should be visible or not.
    $vars->{'delete_enabled'} = $Codestriker::allow_delete;

    # Indicate if the "list/search" functionality is available or not.
    $vars->{'searchlist_enabled'} = $Codestriker::allow_searchlist;

    # Obtain the view topic summary information, the title, bugs it relates
    # to, and who the participants are.
    $vars->{'escaped_title'} = CGI::escapeHTML($document_title);

    if ($Codestriker::antispam_email) {
	$document_author = Codestriker->make_antispam_email($document_author);
    }
    $vars->{'document_author'} = $document_author;
    
    $vars->{'document_creation_time'} = $document_creation_time;
    
    if ($document_bug_ids ne "") {
	my @bugs = split ', ', $document_bug_ids;
	my $bug_string = "";
	for (my $i = 0; $i <= $#bugs; $i++) {
	    $bug_string .=
		$query->a({href=>"$Codestriker::bugtracker$bugs[$i]"},
			  $bugs[$i]);
	    $bug_string .= ', ' unless ($i == $#bugs);
	}
	$vars->{'bug_string'} = $bug_string;
    } else {
	$vars->{'bug_string'} = "";
    }

    if ($Codestriker::antispam_email) {
	$document_reviewers =
	    Codestriker->make_antispam_email($document_reviewers);
    }
    $vars->{'document_reviewers'} = $document_reviewers;
    $vars->{'repository'} = $repository_url;
    $vars->{'number_of_lines'} = $#document + 1;

    # Prepare the data for displaying the state update option.
    $vars->{'mode'} = $mode;
    $vars->{'version'} = $version;
    $vars->{'states'} = \@Codestriker::topic_states;
    $vars->{'default_state'} = $topic_state;

    # Obtain the topic description, with "Bug \d\d\d" links rendered to links
    # to the bug tracking system.
    my $data = "";
    for (my $i = 0; $i <= $#document_description; $i++) {
	$data .= $document_description[$i] . "\n";
    }
    
    $data = $http_response->escapeHTML($data);

    # Replace occurances of bug strings with the appropriate links.
    if ($Codestriker::bugtracker ne "") {
	$data =~ s/(\b)([Bb][Uu][Gg]\s*(\d+))(\b)/$1<A HREF="${Codestriker::bugtracker}$3">$1$2$4<\/A>/mg;
    }
    $vars->{'description'} = $data;

    # Obtains how many comments there are, and the internal link to them.
    $vars->{'number_comments'} = $#comments + 1;
    $vars->{'comment_url'} =
	$url_builder->view_comments_url($topic);

    # Obtain the link to download the actual document text.
    $vars->{'download_url'} = $url_builder->download_url($topic);

    # Fire the template on the topic heading information.
    my $template = Codestriker::Http::Template->new("viewtopic");
    $template->process($vars) || die $template->error();

    # The rest of the output is non-template driven, as it is quite
    # complex.

    # Give the user the option of swapping between diff view modes.
    # If there are no files associated with the review, remove this
    # option.
    if ($#filenames != -1) {
	my $normal_url = $url_builder->view_url($topic, -1,
						$Codestriker::NORMAL_MODE);
	my $coloured_url =
	    $url_builder->view_url($topic, -1, $Codestriker::COLOURED_MODE);
	my $coloured_mono_url =
	    $url_builder->view_url($topic, -1,
				   $Codestriker::COLOURED_MONO_MODE);
	
	if ($mode == $Codestriker::COLOURED_MODE) {
	    print "View as (", $query->a({href=>$normal_url}, "plain"), " | ",
	    $query->a({href=>$coloured_mono_url}, "coloured monospace"),
	    ") diff.\n";
	} elsif ($mode == $Codestriker::COLOURED_MONO_MODE) {
	    print "View as (", $query->a({href=>$normal_url}, "plain"), " | ",
	    $query->a({href=>$coloured_url}, "coloured variable-width"),
	    ") diff.\n";
	} else {
	    print "View as (", $query->a({href=>$coloured_url},
					 "coloured variable-width"), " | ",
	    $query->a({href=>$coloured_mono_url}, "coloured monospace"),
	    ") diff.\n";
	}
	print $query->br;
    }

    # Display the option to change the tab width.
    my $newtabwidth = ($tabwidth == 4) ? 8 : 4;
    my $change_tabwidth_url;
    $change_tabwidth_url =
	$url_builder->view_url_extended($topic, -1, $mode, $newtabwidth,
					"", "", 0);

    print "Tab width set to $tabwidth (";
    print $query->a({href=>"$change_tabwidth_url"},"change to $newtabwidth");
    print ")\n";

    print $query->p if ($mode == $Codestriker::NORMAL_MODE);
    
    # Number of characters the line number should take.
    my $max_digit_width = length($#document+1);

    # Build the render which will be used to build this page.
    my $render = Codestriker::Http::Render->new($query, $url_builder, 0,
						$max_digit_width, $topic,
						$mode, \@comments, $tabwidth,
						$repository, \@filenames,
						\@revisions, \@binary);

    # Display the data that is being reviewed.
    $render->start();

    # Retrieve the delta set comprising this review.
    my @deltas = Codestriker::Model::File->get_delta_set($topic);

    # Render the deltas.
    my $old_filename = "";
    for (my $i = 0; $i <= $#deltas; $i++) {
	my $delta =  $deltas[$i];

	print STDERR "Got!! filenumber: " . $delta->{filenumber} . "\n";
	$render->delta($delta->{filename}, $delta->{filenumber},
		       $delta->{revision}, $delta->{old_linenumber},
		       $delta->{new_linenumber}, $delta->{text},
		       $delta->{description});
    }

    $render->finish();
    print $query->p, $query->a({href=>$view_comments_url},
			       "View all comments");
    
    # Render the HTML trailer.
    my $trailer = Codestriker::Http::Template->new("trailer");
    $trailer->process() || die $trailer->error();

    print $query->end_html();
}

1;
