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
    my $parallel = $http_input->get('parallel');

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

    # Output the new file, with the deltas applied.
    my $title;
    if ($parallel) {
	$title = "Parallel view of $filename v$revision";
    } else {
	$title = $new ? "New $filename" : "$filename v$revision";
    }

    $http_response->generate_header($topic, $title, "", "", "", $mode,
				    $tabwidth, $repository_url, "", "", 0, 1);

    # Render the HTML header.
    my $vars = {};
    $vars->{'version'} = $Codestriker::VERSION;
    my $header = Codestriker::Http::Template->new("header");
    $header->process($vars);

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
				       \@toc_revisions, \@toc_binaries,
				       $max_line_length);
    # Prepare the output.

    if ($parallel) {
	$render->print_coloured_table();
    }
    else {
	print "<PRE class=\"ms\">\n";
    }

    # Read through all the deltas, and apply them to the original form of the
    # file.
    my $delta = undef;
    for (my $delta_index = 0; $delta_index <= $#deltas; $delta_index++) {
	$delta = $deltas[$delta_index];

	# Output those lines leading up to the start of the next delta.
	# Build up a delta with no changes, and render it.
	my $delta_text = "";
	my $next_delta_linenumber = $delta->{old_linenumber};
	for (my $i = $render->{old_linenumber};
	     $i < $next_delta_linenumber; $i++) {
	    $delta_text .= " $filedata[$i]\n";
	}
	$render->delta_text($filename, $fn, $revision,
			    $render->{old_linenumber},
			    $render->{new_linenumber},
			    $delta_text, 0, $new, 0);
			    
	# Render the actual change delta.
	$render->delta_text($filename, $fn, $revision,
			    $delta->{old_linenumber},
			    $delta->{new_linenumber}, $delta->{text}, 1,
			    $new, 1);
    }

    # Render the tail part of the file, again by building up a delta.
    my $delta_text = "";
    for (my $i = $render->{old_linenumber}; $i <= $#filedata; $i++) {
	$delta_text .= " $filedata[$i]\n";
    }
    $render->delta_text($filename, $fn, $revision, $render->{old_linenumber},
			$render->{new_linenumber}, $delta_text, 0, $new, 0);
    
    # Close off the rendering.    
    if ($parallel) {
	print $query->end_table();
    }
    else {
	print "</PRE>\n";
    }

    # Render the HTML trailer.
    my $trailer = Codestriker::Http::Template->new("trailer");
    $trailer->process();

    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [ 0 ], undef);
    
    print $query->end_html();

    $http_response->generate_footer();
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
