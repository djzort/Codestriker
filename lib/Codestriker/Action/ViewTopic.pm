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

    # Retrieve the appropriate topic details.
    my ($document_author, $document_title, $document_bug_ids,
	$document_reviewers, $document_cc, $description,
	$topic_data, $document_creation_time, $document_modified_time,
	$topic_state, $version, $repository_url);
    Codestriker::Model::Topic->read($topic, \$document_author,
				    \$document_title, \$document_bug_ids,
				    \$document_reviewers, \$document_cc,
				    \$description, \$topic_data,
				    \$document_creation_time,
				    \$document_modified_time, \$topic_state,
				    \$version, \$repository_url);

    # Retrieve the changed files which are a part of this review.
    my (@filenames, @revisions, @offsets, @binary);
    Codestriker::Model::File->get_filetable($topic, \@filenames,
					    \@revisions, \@offsets, \@binary);

    # If there are no files associated with this topic, there is no point
    # showing a coloured mode - drop back to the text view.
    if ($#filenames == -1) {
	$mode = $Codestriker::NORMAL_MODE;
    }

    # Retrieve the repository object.
    my $repository =
	Codestriker::Repository::RepositoryFactory->get($repository_url);
    my $repository_root = defined $repository ? $repository->getRoot() : "";

    # Retrieve line-by-line versions of the data and description.
    my @document_description = split /\n/, $description;
    my @document = split /\n/, $topic_data;

    # Retrieve the comment details for this topic.
    my (@comment_linenumber, @comment_author, @comment_data, @comment_date,
	%comment_exists);
    Codestriker::Model::Comment->read($topic, \@comment_linenumber,
				      \@comment_data, \@comment_author,
				      \@comment_date, \%comment_exists);

    $http_response->generate_header($topic, $document_title, $email,
				    "", "", $mode, $tabwidth, $repository_url,
				    "", 0, 1);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'topicid'} = $topic;

    # Create the necessary template variables for generating the heading part
    # of the view topic display.

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Obtains the "Create a new topic", "Search" and "Open topics" URLs.
    $vars->{'create_topic_url'} = $url_builder->create_topic_url();
    $vars->{'search_url'} = $url_builder->search_url();
    my @topic_states = (0);
    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", \@topic_states);

    # Display the "update" message if the topic state has been changed.
    $vars->{'updated'} = $http_input->get('updated') ? 1 : 0;

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
    $vars->{'number_comments'} = $#comment_linenumber + 1;
    $vars->{'comment_url'} =
	$url_builder->view_url($topic, -1, $mode) . "#comments";

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
						$mode, \%comment_exists,
						\@comment_linenumber,
						\@comment_data, $tabwidth,
						$repository, \@filenames,
						\@revisions, \@binary);

    # Record of the current CVS file being diffs (if the file is a
    # unidiff diff file).
    my $current_file = "";
    my $current_file_revision = "";
    my $current_old_file_linenumber = "";
    my $current_new_file_linenumber = "";
    my $diff_linenumbers_found = 0;
    my $reading_diff_block = 0;
    my $cvsmatch = 0;
    my $index_filename = "";
    my $block_description = "";

    # Display the data that is being reviewed.
    $render->start();

    for (my $i = 0; $i <= $#document; $i++) {

	# Check for uni-diff information.
	if ($document[$i] =~ /^===================================================================$/) {
	    # The start of a diff block, reset all the variables.
	    $current_file = "";
	    $current_file_revision = "";
	    $current_old_file_linenumber = "";
	    $current_new_file_linenumber = "";
	    $block_description = "";
	    $reading_diff_block = 1;
	    $cvsmatch = 0;
	} elsif ($document[$i] =~ /^Index: (.*)$/o &&
		 ($mode == $Codestriker::COLOURED_MODE ||
		  $mode == $Codestriker::COLOURED_MONO_MODE)) {
	    $index_filename = $1;
	    next;
	} elsif ($document[$i] =~ /^\?/o &&
		 ($mode == $Codestriker::COLOURED_MODE ||
		  $mode == $Codestriker::COLOURED_MONO_MODE)) {
	    next;
	} elsif ($document[$i] =~ /^RCS file: $repository_root\/(.*),v$/) {
	    # The part identifying the file.
	    $current_file = $1;
	    $cvsmatch = 1;
	} elsif ($document[$i] =~ /^RCS file:/o) {
	    # A new file (or a file that doesn't match CVS repository path).
	    $current_file = $index_filename;
	    $index_filename = "";
	    $cvsmatch = 0;
	} elsif ($document[$i] =~ /^retrieving revision (.*)$/o) {
	    # The part identifying the revision.
	    $current_file_revision = $1;
	} elsif ($document[$i] =~ /^diff/o && $reading_diff_block == 0) {
	    # The start for an ordinary patch file.
	    $current_file = "";
	    $current_file_revision = "";
	    $current_old_file_linenumber = "";
	    $current_new_file_linenumber = "";
	    $block_description = "";
	    $reading_diff_block = 1;
	    $cvsmatch = 0;
	} elsif ($document[$i] =~ /^\-\-\- (.+?)\t.*$/o &&
		 $current_file eq "") {
	    # This is likely to be an ordinary patch file - not a CVS one, in
	    # which case this is the start of the diff block.
	    $current_file = $1;
	    $index_filename = "";
	} elsif ($document[$i] =~ /^\@\@ \-(\d+),\d+ \+(\d+),\d+ \@\@(.*)$/o) {
	    # The part identifying the line number.
	    $current_old_file_linenumber = $1;
	    $current_new_file_linenumber = $2;
	    $block_description = $3;
	    $diff_linenumbers_found = 1;
	    $reading_diff_block = 0;
	}

	# Display the data.
	if ($mode == $Codestriker::NORMAL_MODE) {
	   $render->display_data($i, $document[$i], $current_file,
				 $current_file_revision,
				 $current_old_file_linenumber,
				 $current_new_file_linenumber,
				 $reading_diff_block,
				 $diff_linenumbers_found,
				 $cvsmatch, $block_description);
	} else {
	    $render->display_coloured_data($i, $i, $i, $document[$i],
					   $current_file,
					   $current_file_revision,
					   $current_old_file_linenumber,
					   $current_new_file_linenumber,
					   $reading_diff_block,
					   $diff_linenumbers_found, $cvsmatch,
					   $block_description);
	}

	# Reset the diff line numbers read, to handle the next diff block.
	if ($diff_linenumbers_found) {
	    $diff_linenumbers_found = 0;
	    $current_old_file_linenumber = "";
	    $current_new_file_linenumber = "";
	}
    }

    $render->finish();
    print $query->p;
    
    # Now display all comments in reverse order.  Put an anchor in for the
    # first comment.
    print $query->a({name=>"comments"}, $query->hr);
    print $query->p;

    $vars = {};
    my @comments = ();
    for (my $i = $#comment_linenumber; $i >= 0; $i--) {
	my $comment = {};
	my $edit_url =
	    $url_builder->edit_url($comment_linenumber[$i], $topic, "", "C$i",
				   "");
	my $author;
	if ($Codestriker::antispam_email) {
	    $author = Codestriker->make_antispam_email($comment_author[$i]);
	} else {
	    $author = $comment_author[$i];
	}

	$comment->{'lineurl'} = "javascript:myOpen('$edit_url', 'e')";
	$comment->{'linename'} = "C$i";
	$comment->{'line'} = "line $comment_linenumber[$i]";
	$comment->{'author'} = $author;
	$comment->{'date'} = $comment_date[$i];
	$comment->{'text'} = $http_response->escapeHTML($comment_data[$i]);
	push @comments, $comment;
    }
    $vars->{'comments'} = \@comments;
    my $listcomments = Codestriker::Http::Template->new("listcomments");
    $listcomments->process($vars) || die $listcomments->error();

    # Render the HTML trailer.
    my $trailer = Codestriker::Http::Template->new("trailer");
    $trailer->process() || die $trailer->error();

    print $query->end_html();
}

1;
