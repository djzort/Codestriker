###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the viewing of a file.

package Codestriker::Action::ViewFile;

use strict;

use Codestriker::Model::File;
use Codestriker::Model::Comment;
use Codestriker::Http::Render;
use Codestriker::Repository::RepositoryFactory;

# If the input is valid, display the topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    # Retrieve the parameters for this action.
    my $query = $http_response->get_query();
    my $topic = $http_input->get('topic');
    my $mode = $http_input->get('mode');
    my $tabwidth = $http_input->get('tabwidth');
    my $fn = $http_input->get('fn');
    my $new = $http_input->get('new');

    # Check if this action is allowed.
    if ($Codestriker::allow_repositories == 0) {
	$http_response->error("This function has been disabled");
    }

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

    # Retrieve the corresponding repository object.
    my $repository =
	    Codestriker::Repository::RepositoryFactory->get($repository_url);

    # Retrieve the deltas corresponding to this file.
    my @deltas = Codestriker::Model::File->get_deltas($topic, $fn);
    my $filename = $deltas[0]->{filename};
    my $revision = $deltas[0]->{revision};

    # Retrieve the comment details for this topic.
    my @comments = Codestriker::Model::Comment->read($topic);

    # Load the appropriate original form of this file into memory.
    my ($filedata_max_line_length, @filedata);
    if (!_read_repository_file($filename, $revision, $tabwidth,
			       $repository, \@filedata,
			       \$filedata_max_line_length)) {
	$http_response->error("Couldn't get repository data for $filename " .
			      "$revision: $!");
    }

    # This could be done more efficiently, but for now, read through the
    # file, and determine the longest line length for the resulting
    # data that is to be viewed.  Note it is not 100% accurate, but it will
    # do for now, to reduce the resulting page size.
    my $max_line_length = $filedata_max_line_length;
    for (my $d = 0; $d <= $#deltas; $d++) {
	my @difflines = split /\n/, $deltas[$d]->{text};
	for (my $i = 0; $i <= $#difflines; $i++) {
	    my $line = $difflines[$i];
	    if ($line =~ /^\s(.*)$/o || $line =~ /^\+(.*)$/o ||
		$line =~ /^\-(.*)$/o) {
		my $line_length = length($1);
		if ($line_length > $max_line_length) {
		    $max_line_length = $line_length;
		}
	    }
	}
    }

    # Output the new file, with the delats applied.
    my $title = $new == $UrlBuilder::NEW_FILE ?
	"New $filename" : "$filename v$revision";
    $http_response->generate_header($topic, $title, "", "", "", $mode,
				    $tabwidth, $repository_url, "", 0, 1);

    # Render the HTML header.
    my $header = Codestriker::Http::Template->new("header");
    $header->process() || die $header->error();

    my $parallel = ($new == $UrlBuilder::BOTH_FILES) ? 1 : 0;
    my $max_digit_width = length($#filedata);

    # Create a new render object to perform the line rendering.
    my @toc_filenames = ();
    my @toc_revisions = ();
    my @toc_binaries = ();
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);
    my $render =
	Codestriker::Http::Render->new($query, $url_builder, $parallel,
				       $max_digit_width, $topic, $mode,
				       \@comments, $tabwidth,
				       $repository, \@toc_filenames,
				       \@toc_revisions, \@toc_binaries);
    # Print the heading information.
    if ($new == $UrlBuilder::BOTH_FILES) {
	$render->print_coloured_table();
    }
    else {
	print "<PRE class=\"ms\">\n";
    }

    # Read through all the deltas, and apply them to the original form of the
    # file.
    my $linenumber = 1;
    my $old_linenumber = 1;
    my $new_linenumber = 1;
    my $chunk_end = 1;
    my $next_chunk_end = 1;
    for (my $d = 0; $d <= $#deltas; $d++) {
	my $delta = $deltas[$d];

	my $patch_line_start = $delta->{old_linenumber};
	
	# Output those lines leading up to $patch_line_start.  These lines
	# are not part of the review, so they can't be acted upon.
	for (my $i = $chunk_end; $i < $patch_line_start; $i++, $linenumber++) {
	    if ($new == $UrlBuilder::BOTH_FILES) {
		$render->display_coloured_data(-1, " $filedata[$i]");
		$old_linenumber++;
		$new_linenumber++;
	    }
	    else {
		print $render->render_monospaced_line($linenumber,
						      $filedata[$i], -1,
						      $max_line_length, "");
	    }
	}
	
	# Read the information from the patch, and "apply" it to the
	# output.
	my @difflines = split /\n/, $delta->{text};
	my $patch_index = 0;
	while ($patch_index <= $#difflines) {
	    $_ = $difflines[$patch_index++];
	    my $data = Codestriker::Http::Render->tabadjust($tabwidth, $_, 0);

	    # Handle the processing of the side-by-side view separately.
	    if ($new == $UrlBuilder::BOTH_FILES &&
		($data =~ /^\s/o || $data =~ /^\-/o || $data =~ /^\+/o ||
		 $data =~ /^$/o)) {
		$render->display_coloured_data(-1, $_);
		$old_linenumber++ if $data =~ /^\s/o || $data =~ /^\-/o;
		$new_linenumber++ if $data =~ /^\s/o || $data =~ /^\+/o;
		next;
	    }

	    my $offset = 0;
	    if (/^\-(.*)$/o) {
		# A removed line.
		$render->add_minus_monospace_line($1, $offset);
	    } elsif (/^\+(.*)$/o) {
		# An added line.
		$render->add_plus_monospace_line($1, $offset);
	    } elsif (/^\\/o) {
		# A line with a diff comment, such as:
		# \ No newline at end of file.
		# The easiest way to deal with these lines is to just ignore
		# them.
	    } else {
		# An unchanged line, output it and anything pending, and remove
		# the leading space for alignment reasons.
		my $linedata = $_;
		$linedata =~ s/^\s//;
		$render->flush_monospaced_lines(\$linenumber,
						$max_line_length, $new);
		print $render->render_monospaced_line($linenumber, $linedata,
						      $offset,
						      $max_line_length, "");
		$linenumber++;
	    }
	}
	if ($new != $UrlBuilder::BOTH_FILES) {
	    $render->flush_monospaced_lines(\$linenumber,
					    $max_line_length, $new);
	}

	$chunk_end = $next_chunk_end;

	if ($patch_index > $#difflines) {
	    if ($new != $UrlBuilder::BOTH_FILES) {
		# Reached the end of the patch file.  Flush anything pending.
		$render->flush_monospaced_lines(\$linenumber,
						$max_line_length, $new);
	    }
	    else {
		# Flush anything pending.
		$render->render_changes();
	    }
	    last;
	}
    }

    # Display the last part of the file.
    for (my $i = $chunk_end; $i <= $#filedata; $i++, $linenumber++) {
	if ($new == $UrlBuilder::BOTH_FILES) {
	    $render->display_coloured_data($old_linenumber,
					   $new_linenumber, -1,
					   " $filedata[$i]", "", "",
					   $old_linenumber,
					   $new_linenumber, 0, 0, 1, "");
	    $old_linenumber++;
	    $new_linenumber++;
	}
	else {
	    print $render->render_monospaced_line($linenumber,
						  $filedata[$i], -1,
						  $max_line_length, "");
	}
    }

    if ($new == $UrlBuilder::BOTH_FILES) {
	print $query->end_table();
    }
    else {
	print "</PRE>\n";
    }

    # Render the HTML trailer.
    my $trailer = Codestriker::Http::Template->new("trailer");
    $trailer->process() || die $trailer->error();

    print $query->end_html();
}

# Read the specified repository file and revision into memory.  Return true if
# successful, false otherwise.
sub _read_repository_file ($$$$$$) {
    my ($filename, $revision, $tabwidth, $repository, $data_array_ref,
	$maxline_length_ref) = @_;

    # Read the file data.
    $repository->retrieve($filename, $revision, $data_array_ref);

    # Determine the maximum line length, and replace tabs with spaces.
    $$maxline_length_ref = 0;
    for (my $i = 1; $i <= $#$data_array_ref; $i++) {
	$$data_array_ref[$i] =
	    Codestriker::Http::Render->tabadjust($tabwidth,
						 $$data_array_ref[$i], 0);
	my $line_length = length($$data_array_ref[$i]);
	if ($line_length > $$maxline_length_ref) {
	    $$maxline_length_ref = $line_length;
	}
    }
    return 1;
}

1;
