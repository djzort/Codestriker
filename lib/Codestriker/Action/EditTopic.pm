###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for adding a comment to a topic line.

package Codestriker::Action::EditTopic;

use strict;

# Create an appropriate form for adding a comment to a topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    # Obtain a new URL builder object.
    my $query = $http_response->get_query();
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Retrieve the appropriate input fields.
    my $line = $http_input->get('line');
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
    my (@comment_linenumber, @comment_author, @comment_data, @comment_date,
	%comment_exists);
    Codestriker::Model::Comment->read($topic, \@comment_linenumber,
				      \@comment_data, \@comment_author,
				      \@comment_date, \%comment_exists);

    # Retrieve line-by-line versions of the data and description.
    my @document_description = split /\n/, $description;
    my @document = split /\n/, $topic_data;

    # Display the header of this page.
    $http_response->generate_header($topic, $document_title, $email, "", "",
				    $mode, $tabwidth, $repository, "", 0, 0);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'topic_title'} = "Edit topic: $document_title";
    if ($Codestriker::antispam_email) {
	$document_author = Codestriker->make_antispam_email($document_author);
	$document_reviewers =
	    Codestriker->make_antispam_email($document_reviewers);
	$document_cc = Codestriker->make_antispam_email($document_cc);
    }
    $vars->{'author'} = $document_author;
    $vars->{'reviewers'} = $document_reviewers;

    if (defined $document_cc && $document_cc ne "") {
	$vars->{'cc'} = $document_cc;
    } else {
	$vars->{'cc'} = "";
    }

    my $view_url = $url_builder->view_url($topic, $line, $mode);
    $vars->{'view_url'} = $view_url;

    # Retrieve the context in question.  Allow the user to increase it
    # or decrease it appropriately.
    my $inc_context = ($context <= 0) ? 1 : $context*2;
    my $dec_context = ($context <= 0) ? 0 : int($context/2);
    my $inc_context_url =
	$url_builder->edit_url($line, $topic, $inc_context, "", "");
    my $dec_context_url =
	$url_builder->edit_url($line, $topic, $dec_context, "", "");
    $vars->{'inc_context_url'} = $inc_context_url;
    $vars->{'dec_context_url'} = $dec_context_url;

    $vars->{'context'} =
	$query->pre(Codestriker::Http::Render->get_context($line, $topic,
							   $context, 1,
							   \@document)) .
							   $query->p . "\n";

    # Display the comments which have been made for this line number
    # thus far in reverse order.
    my @comments = ();
    for (my $i = $#comment_linenumber; $i >= 0; $i--) {
	if ($comment_linenumber[$i] == $line) {
	    my $comment = {};
	    my $author = $comment_author[$i];
	    if ($Codestriker::antispam_email) {
		$author = Codestriker->make_antispam_email($author);
	    }
	    $comment->{'author'} = $author;
	    $comment->{'date'} = $comment_date[$i];
	    $comment->{'text'} = $http_response->escapeHTML($comment_data[$i]);
	    $comment->{'line'} = "";
	    $comment->{'lineurl'} = "";
	    $comment->{'linename'} = "";
	    push @comments, $comment;
	}
    }
    $vars->{'comments'} = \@comments;

    # Populate the form values.
    $vars->{'line'} = $line;
    $vars->{'topicid'} = $topic;
    $vars->{'mode'} = $mode;
    $vars->{'anchor'} = $anchor;
    $vars->{'email'} = $email;

    # Display the output via the template.
    my $template = Codestriker::Http::Template->new("edittopic");
    $template->process($vars) || die $template->error();
}

1;
