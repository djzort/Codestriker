###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for adding a comment to a topic line.

package Codestriker::Action::EditTopic;

use strict;
use Codestriker::Action::SubmitComment;
use Codestriker::Model::Topic;
use Codestriker::Http::Render;

# Create an appropriate form for adding a comment to a topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    # Obtain a new URL builder object.
    my $query = $http_response->get_query();
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Retrieve the appropriate input fields.
    my $line = $http_input->get('line');
    my $fn = $http_input->get('fn');
    my $new = $http_input->get('new');
    my $topic = $http_input->get('topic');
    my $context = $http_input->get('context');
    my $email = $http_input->get('email');
    my $mode = $http_input->get('mode');
    my $tabwidth = $http_input->get('tabwidth');
    my $anchor = $http_input->get('a');

    # Retrieve the appropriate topic details.
    my ($document_author, $document_title, $document_bug_ids,
	$document_reviewers, $document_cc, $description,
	$topic_data, $document_creation_time, $document_modified_time,
	$topic_state, $version, $repository);
    my $rc = Codestriker::Model::Topic->read($topic, \$document_author,
					     \$document_title,
					     \$document_bug_ids,
					     \$document_reviewers,
					     \$document_cc,
					     \$description, \$topic_data,
					     \$document_creation_time,
					     \$document_modified_time,
					     \$topic_state,
					     \$version, \$repository);


    if ($rc == $Codestriker::INVALID_TOPIC) {
	# Topic no longer exists, most likely its been deleted.
	$http_response->error("Topic no longer exists.");
    }

    # Retrieve the comment details for this topic.
    my @comments = Codestriker::Model::Comment->read_same_line($topic, $fn, $line, $new);

    # Retrieve line-by-line versions of the description.
    my @document_description = split /\n/, $description;

    # Retrieve the diff hunk for this file and line number.
    my $delta = Codestriker::Model::File->get_delta($topic, $fn, $line, $new);

    # Display the header of this page.
    $http_response->generate_header($topic, $document_title, $email, "", "",
				    $mode, $tabwidth, $repository, "", "",
				    0, 0);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'version'} = $Codestriker::VERSION;
    $vars->{'topic_title'} = "Edit topic: $document_title";
    if ($Codestriker::antispam_email) {
	$document_author = Codestriker->make_antispam_email($document_author);
	$document_reviewers =
	    Codestriker->make_antispam_email($document_reviewers);
	$document_cc = Codestriker->make_antispam_email($document_cc);
    }
    $vars->{'author'} = $document_author;
    $vars->{'reviewers'} = $document_reviewers;

    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [ 0 ], undef);
    
    if (defined $document_cc && $document_cc ne "") {
	$vars->{'cc'} = $document_cc;
    } else {
	$vars->{'cc'} = "";
    }

    my $view_topic_url =
	$url_builder->view_url($topic, $line, $mode,
			       $Codestriker::default_topic_br_mode);

    my $view_comments_url = $url_builder->view_comments_url($topic);
    $vars->{'view_topic_url'} = $view_topic_url;
    $vars->{'view_comments_url'} = $view_comments_url;
    $vars->{'doc_url'} = $url_builder->doc_url();

    # Retrieve the context in question.  Allow the user to increase it
    # or decrease it appropriately.
    my $inc_context = ($context <= 0) ? 1 : $context*2;
    my $dec_context = ($context <= 0) ? 0 : int($context/2);
    my $inc_context_url =
	$url_builder->edit_url($fn, $line, $new, $topic, $inc_context, "", "");
    my $dec_context_url =
	$url_builder->edit_url($fn, $line, $new, $topic, $dec_context, "", "");
    $vars->{'inc_context_url'} = $inc_context_url;
    $vars->{'dec_context_url'} = $dec_context_url;

    $vars->{'context'} = $query->pre(
	    Codestriker::Http::Render->get_context($line, 
						   $context, 1,
						   $delta->{old_linenumber},
						   $delta->{new_linenumber},
						   $delta->{text},
						   $new)) .
						       $query->p . "\n";

    # Display the comments which have been made for this line number
    # in chronological order.
    my @display_comments = ();
    for (my $i = 0; $i <= $#comments; $i++) {
	my $display_comment = {};
	my $author = $comments[$i]{author};
	if ($Codestriker::antispam_email) {
	    $display_comment->{author} =
		Codestriker->make_antispam_email($author);
	} else {
	    $display_comment->{author} = $author;
	}
	$display_comment->{date} = $comments[$i]{date};
	$display_comment->{data} = $comments[$i]{data};
	$display_comment->{line} = "";
	$display_comment->{lineurl} = "";
	$display_comment->{linename} = "";
	push @display_comments, $display_comment;
    }
    $vars->{'comments'} = \@display_comments;

    # Populate the form values.
    $vars->{'line'} = $line;
    $vars->{'topicid'} = $topic;
    $vars->{'mode'} = $mode;
    $vars->{'anchor'} = $anchor;
    $vars->{'email'} = $email;
    $vars->{'fn'} = $fn;
    $vars->{'new'} = $new;

    # Display the output via the template.
    my $template = Codestriker::Http::Template->new("edittopic");
    $template->process($vars);

    $http_response->generate_footer();
}

1;
