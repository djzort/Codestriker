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
	$topic_state, $version);
    Codestriker::Model::Topic->read($topic, \$document_author,
				    \$document_title, \$document_bug_ids,
				    \$document_reviewers, \$document_cc,
				    \$description, \$topic_data,
				    \$document_creation_time,
				    \$document_modified_time, \$topic_state,
				    \$version);

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
				    "", "", $mode, $tabwidth, "", 0);
    
    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Display the "Create a new topic" and "Search" links.
    my $create_topic_url = $url_builder->create_topic_url();
    my $search_url = $url_builder->search_url();
    print $query->a({href=>$create_topic_url}, "Create a new topic") . " | ";
    print $query->a({href=>$search_url}, "Search") . "\n";
    print $query->p;

    # Display the view topic summary information, the title, bugs it relates
    # to, and who the participants are.
    my $escaped_title = CGI::escapeHTML($document_title);
    print $query->h2("$escaped_title"), "\n";

    print $query->start_table();
    print $query->Tr($query->td("Author: "),
		     $query->td($document_author)), "\n";
    print $query->Tr($query->td("Created: "),
		     $query->td($document_creation_time)), "\n";
    if ($document_bug_ids ne "") {
	my @bugs = split ', ', $document_bug_ids;
	my $bug_string = "";
	for (my $i = 0; $i <= $#bugs; $i++) {
	    $bug_string .=
		$query->a({href=>"$Codestriker::bugtracker$bugs[$i]"},
			  $bugs[$i]);
	    $bug_string .= ', ' unless ($i == $#bugs);
	}
	print $query->Tr($query->td("Bug IDs: "),
			 $query->td($bug_string));
    }
    print $query->Tr($query->td("Reviewers: "),
		     $query->td($document_reviewers)), "\n";
    if (defined $document_cc && $document_cc ne "") {
	print $query->Tr($query->td("Cc: "),
			 $query->td($document_cc)), "\n";
    }
    print $query->Tr($query->td("Number of lines: "),
		     $query->td($#document + 1)), "\n";

    # Display the current topic state, and a simple form for changing it.
    print $query->start_form();
    $query->param(-name=>'action', -value=>'change_topic_state');
    print $query->hidden(-name=>'action', -default=>'change_topic_state');
    print $query->hidden(-name=>'topic', -default=>"$topic");
    print $query->hidden(-name=>'mode', -default=>"$mode");
    print $query->hidden(-name=>'version', -default=>"$version");
    my $state_cell =
	$query->popup_menu(-name=>'topic_state',
			   -values=>\@Codestriker::topic_states,
			   -default=>$topic_state)
	. $query->submit(-value=>'Update');
    print $query->Tr($query->td("State: "),
		     $query->td($state_cell)) . "\n";
    print $query->end_form();
    print $query->end_table(), "\n";


    # Output the topic description, with "Bug \d\d\d" links rendered to links
    # to the bug tracking system.
    print "<PRE>\n";
    my $data = "";
    for (my $i = 0; $i <= $#document_description; $i++) {
	$data .= $document_description[$i] . "\n";
    }
    
    $data = $http_response->escapeHTML($data);

    # Replace occurances of bug strings with the appropriate links.
    if ($Codestriker::bugtracker ne "") {
	$data =~ s/(\b)([Bb][Uu][Gg]\s*(\d+))(\b)/$1<A HREF="${Codestriker::bugtracker}$3">$1$2$4<\/A>/mg;
    }
    print $data;
    print "</PRE>\n";

    # Display how many comments there are, with an internal link to them.
    my $number_comments = $#comment_linenumber + 1;
    my $url = $url_builder->view_url($topic, -1, $mode);
    if ($number_comments == 1) {
	print "Only one ", $query->a({href=>"${url}#comments"},
				     "comment");
	print " submitted.\n", $query->p;
    } elsif ($number_comments > 1) {
	print "$number_comments ", $query->a({href=>"${url}#comments"},
					     "comments");
	print " submitted.\n", $query->p;
    }

    # Display the link to download the actual document text.
    my $download_url = $url_builder->download_url($topic);
    print $query->a({href=>"$download_url"},"Download"), " topic text.\n";

    print $query->p, $query->hr, $query->p;

    # Give the user the option of swapping between diff view modes.
    my $normal_url = $url_builder->view_url($topic, -1,
					    $Codestriker::NORMAL_MODE);
    my $coloured_url =
	$url_builder->view_url($topic, -1, $Codestriker::COLOURED_MODE);
    my $coloured_mono_url =
	$url_builder->view_url($topic, -1, $Codestriker::COLOURED_MONO_MODE);

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

    # Display the option to change the tab width.
    my $newtabwidth = ($tabwidth == 4) ? 8 : 4;
    my $change_tabwidth_url;
    $change_tabwidth_url =
	$url_builder->view_url_extended($topic, -1, $mode, $newtabwidth,
					"", "");

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
						\@comment_data, $tabwidth);

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
	} elsif ($document[$i] =~ /^RCS file: $Codestriker::cvsrep\/(.*),v$/) {
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
	} elsif ($document[$i] =~ /^\-\-\- (.*[^\s])\s+(Mon|Tue|Wed|Thu|Fri|Sat|Sun).*$/o &&
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
    for (my $i = $#comment_linenumber; $i >= 0; $i--) {
	my $edit_url =
	    $url_builder->edit_url($comment_linenumber[$i], $topic, "", "C$i",
				   "");
	if ($i == $#comment_linenumber) {
	    print $query->a({name=>"comments"},$query->hr);
	} else {
	    print $query->hr;
	}
	print $query->a({href=>"javascript:myOpen('$edit_url','e')",
			 name=>"C$i"},
			"line $comment_linenumber[$i]"), ": ";
	print "$comment_author[$i] $comment_date[$i]", $query->br, "\n";
	print $query->pre($http_response->escapeHTML($comment_data[$i])) .
	    $query->p;
    }
}

1;
