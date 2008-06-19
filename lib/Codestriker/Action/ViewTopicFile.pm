###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the viewing of a file.

package Codestriker::Action::ViewTopicFile;

use strict;

use Codestriker::Model::File;
use Codestriker::Model::Comment;
use Codestriker::Repository::RepositoryFactory;

# If the input is valid, display the topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    # Retrieve the parameters for this action.
    my $query = $http_response->get_query();
    my $topicid = $http_input->get('topic');
    my $mode = $http_input->get('mode');
    my $tabwidth = $http_input->get('tabwidth');
    my $email = $http_input->get('email');
    my $fn = $http_input->get('fn');
    my $new = $http_input->get('new');
    my $parallel = $http_input->get('parallel');
    my $fview = $http_input->get('fview');

    # Check if this action is allowed.
    if (scalar(@Codestriker::valid_repositories) == 0) {
	$http_response->error("This function has been disabled");
    }

    # Retrieve the appropriate topic details.
    my $topic = Codestriker::Model::Topic->new($topicid);

    # Retrieve the corresponding repository object.
    my $repository =
	Codestriker::Repository::RepositoryFactory->get($topic->{repository});

    # Retrieve the deltas corresponding to this file.
    my @deltas = Codestriker::Model::Delta->get_deltas($topicid, $fn);

    # We need to untaint the filename and revision values, as they will
    # potentially be used to launch an external program.
    $deltas[0]->{filename} =~ /^(.*)$/o;
    my $filename = $1;
    $deltas[0]->{revision} =~ /^(.*)$/o;
    my $revision = $1;

    # Retrieve the comment details for this topic.
    my @comments = $topic->read_comments();

    # Load the appropriate original form of this file into memory.
    my @filedata;
    if (!$repository->retrieve($filename, $revision, \@filedata)) {
	$http_response->error("Couldn't get repository data for $filename " .
			      "$revision: $!");
    }

    # Output the new file, with the deltas applied.
    my $title;
    if ($parallel) {
	$title = "View File: Parallel view of $filename v$revision";
    } else {
	$title = $new ? "View File: New $filename" :
	    "View File: $filename v$revision";
    }

    $http_response->generate_header(topic=>$topic,
				    comments=>\@comments,
				    topic_title=>$title,
				    mode=>$mode,
				    tabwidth=>$tabwidth,
				    fview=>$fview,
				    repository=>$Codestriker::repository_name_map->{$topic->{repository}}, 
                                    reload=>0, cache=>1);

    # Need to create a single delta object that combines all of the deltas
    # together.
    my $merged_delta = {};
    if (@deltas > 0) {
	my $delta = $deltas[0];
	$merged_delta->{filename} = $delta->{filename};
	$merged_delta->{revision} = $delta->{revision};
	$merged_delta->{binary} = $delta->{binary};
	$merged_delta->{filenumber} = $delta->{filenumber};
	$merged_delta->{repmatch} = $delta->{repmatch};
	$merged_delta->{old_linenumber} = 1;
	$merged_delta->{new_linenumber} = 1;
	$merged_delta->{only_delta_in_file} = 1;
    }
    
    # Now compute the delta text of all the merged deltas.
    my $delta_text = "";
    my $old_linenumber = 1;
    for (my $delta_index = 0; $delta_index <= $#deltas; $delta_index++) {
	my $delta = $deltas[$delta_index];

	# Output those lines leading up to the start of the next delta.
	# Build up a delta with no changes, and render it.
	my $next_delta_linenumber = $delta->{old_linenumber};
	for (my $i = $old_linenumber; $i < $next_delta_linenumber; $i++) {
	    $delta_text .= " $filedata[$i]\n";
	    $old_linenumber++;
	}

	# Keep track of the old linenumber so the blanks between the
	# deltas can be filled in.
	my @diff_lines = split /\n/, $delta->{text};
	foreach my $line (@diff_lines) {
	    if ($line =~ /^\-/o || $line =~ /^\s/o) {
		$old_linenumber++;
	    }
	}

	# Add the text of this delta to the final text.
	$delta_text .= $delta->{text};
    }

    # Add the text from the tail-end of the file.
    for (my $i = $old_linenumber; $i <= $#filedata; $i++) {
	$delta_text .= " $filedata[$i]\n";
    }

    # Now update the merged delta with this text.
    $merged_delta->{text} = $delta_text;

    # Render this delta.
    my @merged_deltas = ();
    push @merged_deltas, $merged_delta;
    my $delta_renderer =
	Codestriker::Http::DeltaRenderer->new($topic, \@comments,
					      \@merged_deltas, $query,
					      $mode, $tabwidth, $repository);
    $delta_renderer->annotate_deltas();

    my $vars = {};
    $vars->{'deltas'} = \@merged_deltas;
    my $template = Codestriker::Http::Template->new("viewtopicfile");
    $template->process($vars);
    $http_response->generate_footer();

    # Fire the topic listener to indicate that the user has viewed the topic.
    Codestriker::TopicListeners::Manager::topic_viewed($email, $topic);
}

1;
