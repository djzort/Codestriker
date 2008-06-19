
###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the viewing of a topic.

package Codestriker::Action::ViewTopic;

use strict;

use HTML::Entities ();

use Codestriker::Model::Topic;
use Codestriker::Model::Comment;
use Codestriker::Http::UrlBuilder;
use Codestriker::Http::DeltaRenderer;
use Codestriker::Repository::RepositoryFactory;
use Codestriker::TopicListeners::Manager;

# If the input is valid, display the topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    
    my $topicid = $http_input->get('topic');
    my $mode = $http_input->get('mode');
    my $fview = $http_input->get('fview');
    my $tabwidth = $http_input->get('tabwidth');
    my $email = $http_input->get('email');
    my $feedback = $http_input->get('feedback');

    if (Codestriker::Model::Topic::exists($topicid) == 0) {
	# Topic no longer exists, most likely its been deleted.
	$http_response->error("Topic no longer exists.");
    }

    # Retrieve the appropriate topic details.           
    my $topic = Codestriker::Model::Topic->new($topicid);     

    # Retrieve the comment details for this topic, firstly determine how
    # many distinct comment lines are there.
    my @comments = $topic->read_comments();
    my %comment_map = ();
    foreach my $comment (@comments) {
	my $key = $comment->{filenumber} . "|" . $comment->{fileline} . "|" .
	    $comment->{filenew};
	if (! exists $comment_map{$key}) {
	    $comment_map{$key} = 1;
	}
    }

    # Retrieve the changed files which are a part of this review.
    my (@filenames, @revisions, @offsets, @binary, @numchanges);
    $topic->get_filestable(
    		\@filenames,
                \@revisions,
                \@offsets,
                \@binary,
                \@numchanges);

    # Retrieve line-by-line versions of the data and description.
    my @document_description = split /\n/, $topic->{description};

    $http_response->generate_header(topic=>$topic,
				    comments=>\@comments,
				    topic_title=>"Topic Text: $topic->{title}",
				    mode=>$mode, tabwidth=>$tabwidth,
				    fview=>$fview,
				    reload=>0, cache=>1);

    # Retrieve the repository object, if repository functionality is enabled.
    my $repository;
    if (scalar(@Codestriker::valid_repositories)) {
	$repository =
	    Codestriker::Repository::RepositoryFactory->get($topic->{repository});
    } else {
	# Indicate not to activate any repository-related links.
	$topic->{repository} = "";
    }

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'feedback'} = $feedback;

    # Create the necessary template variables for generating the heading part
    # of the view topic display.

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    ProcessTopicHeader($vars, $topic, $url_builder);

    # Display the "update" message if the topic state has been changed.
    $vars->{'updated'} = $http_input->get('updated');
    $vars->{'rc_ok'} = $Codestriker::OK;
    $vars->{'rc_stale_version'} = $Codestriker::STALE_VERSION;
    $vars->{'rc_invalid_topic'} = $Codestriker::INVALID_TOPIC;

    if ($topic->{bug_ids} ne "") {
	my @bugs = split ', ', $topic->{bug_ids};
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

    $vars->{'document_reviewers'} = 
    	Codestriker->filter_email($topic->{reviewers});
    $vars->{'project_name'} = $topic->{project_name};
    $vars->{'number_of_lines'} = $topic->get_topic_size_in_lines();

    $vars->{'suggested_topic_size_lines'} =
	$Codestriker::suggested_topic_size_lines eq "" ? 0 :
	$Codestriker::suggested_topic_size_lines;    

    # Prepare the data for displaying the state update option.
    # Make sure the old mode setting is no longer used.
    if ((! defined $mode) || $mode == $Codestriker::NORMAL_MODE) {
	$mode = $Codestriker::COLOURED_MODE;
    }
    if (! defined $fview) {
	    $fview = $Codestriker::default_file_to_view;
	    if (! defined $fview) {
		$fview = -1;
	    }
    }
    $vars->{'states'} = \@Codestriker::topic_states;
    $vars->{'default_state'} = $topic->{state};

    # Set the description of the topic.
    my $data = "";
    for (my $i = 0; $i <= $#document_description; $i++) {
	$data .= $document_description[$i] . "\n";
    }
    $vars->{'description'} = $data;

    # Obtain the link to download the actual document text.
    $vars->{'download_url'} = $url_builder->download_url($topicid);

    # Obtain the links for the different viewing modes.
    $vars->{'coloured_mode_url'} =
	$url_builder->view_url($topicid, -1, $Codestriker::COLOURED_MODE, $fview);
    $vars->{'coloured_mono_mode_url'} =
	$url_builder->view_url($topicid, -1,
			       $Codestriker::COLOURED_MONO_MODE, $fview);
    $vars->{'br_normal_mode_url'} =
	$url_builder->view_url($topicid, -1, $mode,
			       $Codestriker::LINE_BREAK_NORMAL_MODE, $fview);
    $vars->{'br_assist_mode_url'} =
	$url_builder->view_url($topicid, -1, $mode,
			       $Codestriker::LINE_BREAK_ASSIST_MODE, $fview);

    # Set template variables relating to coloured mode.
    if ($mode == $Codestriker::COLOURED_MODE) {
	$vars->{'mode'} = 'coloured';
    } elsif ($mode == $Codestrikier::COLOURED_MONO_MODE) {
	$vars->{'mode'} = 'coloured_mono';
    } else {
	$vars->{'mode'} = 'unknown';
    }

    # Set varibles relating to tab-width setting.
    my $newtabwidth = ($tabwidth == 4) ? 8 : 4;
    $vars->{'tabwidth'} = $tabwidth;
    $vars->{'newtabwidth'} = $newtabwidth;
    $vars->{'change_tabwidth_url'} =
	$url_builder->view_url_extended($topicid, -1, $mode, $newtabwidth,
					"", "", 0, $fview);

    # Set the display all, display single URLs.
    $vars->{'display_all_files_url'} =
	$url_builder->view_url($topicid, -1, $mode, -1);
    $vars->{'display_single_file_url'} =
	$url_builder->view_url($topicid, -1, $mode, 0);
    $vars->{'fview'} = $fview;

    # Setup the filetable template variable for displaying the table of
    # contents.
    my @filetable = ();
    for (my $i = 0; $i <= $#filenames; $i++) {
	my $filerow = {};
	my $filename = $filenames[$i];
	$filerow->{filename} = $filename;
	$filerow->{numchanges} = $numchanges[$i];
	$filerow->{href_filename_url} = 
	    $url_builder->view_url($topicid, -1, $mode, $i) .
	    "#" . $filename;
	$filerow->{binary} = $binary[$i];

	my $revision = $revisions[$i];
	if ($revision eq $Codestriker::ADDED_REVISION) {
	    $filerow->{revision} = 'added';
	} elsif ($revision eq $Codestriker::REMOVED_REVISION) {
	    $filerow->{revision} = 'removed';
	} elsif ($revision eq $Codestriker::PATCH_REVISION) {
	    $filerow->{revision} = 'patch';
	} else {
	    $filerow->{revision} = $revision;
	}
	
	push @filetable, $filerow;
    }
    $vars->{'filetable'} = \@filetable;

    # Determine which deltas are to be retrieved.
    my @deltas = ();
    if ($fview != -1) {
	# Get only the deltas for the selected file.    
        @deltas = Codestriker::Model::Delta->get_delta_set($topicid, $fview);
    }
    else {
	# Get the whole delta data.
        @deltas = Codestriker::Model::Delta->get_delta_set($topicid, -1);
    }

    my $delta_renderer =
	Codestriker::Http::DeltaRenderer->new($topic, \@comments, \@deltas, $query,
					      $mode, $tabwidth, $repository);

    # Set the add general comment URL.
    $vars->{'add_general_comment_element'} =
	$delta_renderer->comment_link(-1, -1, 1, "Add General Comment");

    # Set the per-delta URL links, such as adding a file-level comment,
    # and links to the previous/next file.
    my $current_filename = "";
    foreach my $delta (@deltas) {
    my $filenumber = $delta->{filenumber};	
	$delta->{add_file_comment_element} =
	    $delta_renderer->comment_link($filenumber, -1, 1, "[Add File Comment]");

	# Determine if the file has a link to a repository system,
	# and if so, create the appropriate links.
	if ($delta->{repmatch} &&
	    $delta->{revision} ne $Codestriker::ADDED_REVISION &&
	    $delta->{revision} ne $Codestriker::PATCH_REVISION &&
	    defined $repository) {
	    $delta->{repository_file_view_url} =
		$repository->getViewUrl($delta->{filename});
	    $delta->{view_old_full_url} =
		$url_builder->view_file_url($topicid, $filenumber, 0, $delta->{old_linenumber},
					    $mode, 0);
	    $delta->{view_old_full_both_url} =
		$url_builder->view_file_url($topicid, $filenumber, 0, $delta->{old_linenumber},
					    $mode, 1);
	    $delta->{view_new_full_url} =
		$url_builder->view_file_url($topicid, $filenumber, 1, $delta->{new_linenumber},
					    $mode, 0);
	    $delta->{view_new_full_both_url} =
		$url_builder->view_file_url($topicid, $filenumber, 1, $delta->{new_linenumber},
					    $mode, 1);
	}

	# Create the next/previous file URL links.
    if ($filenumber > 0) {
		$delta->{previous_file_url} =
		    $url_builder->view_url($topicid, -1, $mode,
					   $filenumber-1) . "#" . $filenames[$filenumber-1];
	    }
	    if ($filenumber < $#filenames) {
		$delta->{next_file_url} =
		    $url_builder->view_url($topicid, -1, $mode,
					   $filenumber+1) . "#" . $filenames[$filenumber+1];
	    }

	    $current_filename = $delta->{filename};
    }

    # Annotate the deltas appropriately so that they can be easily rendered.
    $delta_renderer->annotate_deltas();

    $vars->{'deltas'} = \@deltas;

    # Fire the template for generating the view topic screen.
    my $template = Codestriker::Http::Template->new("viewtopic");
    $template->process($vars);
    $http_response->generate_footer();

    # Fire the topic listener to indicate that the user has viewed the topic.
    Codestriker::TopicListeners::Manager::topic_viewed($email, $topic);
}


# This function is used by all of the view topic tabs to fill out the
# common template items that are required by all, in addition to the view
# topic file action.
sub ProcessTopicHeader
{
    my ($vars, $topic, $url_builder) = @_;

    # Handle the links in the three topic tabs.
    $vars->{'view_topicinfo_url'} =
	$url_builder->view_topicinfo_url($topic->{topicid});
    $vars->{'view_topic_url'} =
	## XX mode, last param
	$url_builder->view_url($topic->{topicid}, -1, 0);
    
    $vars->{'view_comments_url'} =
	$url_builder->view_comments_url($topic->{topicid});
    
    $vars->{'view_topic_properties_url'} =
	$url_builder->view_topic_properties_url($topic->{topicid});
    
    my @project_ids = ($topic->{project_id});
    $vars->{'list_open_topics_in_project_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "", "", "",
				      "", [ 0 ], \@project_ids);
    
    # Retrieve the comment details for this topic.
    my @comments = $topic->read_comments();
    
    # Obtains how many comments there are, and the internal link to them.
    $vars->{'number_comments'} = $#comments + 1;
    
    # Obtain the view topic summary information, the title, bugs it relates
    # to, and who the participants are.
    $vars->{'title'} = $topic->{title};
    
    $vars->{'author'} = Codestriker->filter_email($topic->{author});
    
    $vars->{'document_creation_time'} = 
	Codestriker->format_timestamp($topic->{creation_ts});
    
    $vars->{'topic'} = $topic->{topicid};
    
    $vars->{'reviewers'} = Codestriker->filter_email($topic->{reviewers});
    $vars->{'cc'} =  Codestriker->filter_email($topic->{cc});
    
    # Get the list of obsoleted topics.
    my @obsoleted_topics = ();
    foreach my $id (@{ $topic->{obsoleted_topics} }) {
	my $obsoleted_topic = Codestriker::Model::Topic->new($id);
	my $entry = {};
	$entry->{title} = $obsoleted_topic->{title};
	$entry->{view_url} = $url_builder->view_url($id, -1);
	push @obsoleted_topics, $entry;
    }
    $vars->{'obsoleted_topics'} = \@obsoleted_topics;
    
    # Get the list of topics this has been obsoleted by.
    my @obsoleted_by = ();
    foreach my $id (@{ $topic->{obsoleted_by} }) {
	my $superseeded_topic = Codestriker::Model::Topic->new($id);
	my $entry = {};
	$entry->{title} = $superseeded_topic->{title};
	$entry->{view_url} = $url_builder->view_url($id, -1);
	push @obsoleted_by, $entry;
    }
    $vars->{'obsoleted_by'} = \@obsoleted_by;
}


1;
