###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for adding a comment to a topic line.

package Codestriker::Action::EditTopic;

use strict;

# Create an appropriate form for creating a new topic.
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

    # Retrieve the appropriate topic details.
    my ($document_author, $document_title, $document_bug_ids,
	$document_reviewers, $document_cc, $description,
	$topic_data, $document_creation_time, $document_modified_time);
    Codestriker::Model::Topic->read($topic, \$document_author,
				    \$document_title, \$document_bug_ids,
				    \$document_reviewers, \$document_cc,
				    \$description, \$topic_data,
				    \$document_creation_time,
				    \$document_modified_time);

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
				    $mode);
    print $query->h2("Edit topic: $document_title");
    print $query->start_table();
    print $query->Tr($query->td("Author: "),
		     $query->td($document_author));
    print $query->Tr($query->td("Reviewers: "),
		     $query->td($document_reviewers));
    if (defined $document_cc && $document_cc ne "") {
	print $query->Tr($query->td("Cc: "),
			 $query->td($document_cc));
    }
    print $query->end_table();

    my $view_url = $url_builder->view_url($topic, $line, $mode);
    print $query->p, $query->a({href=>"$view_url"},"View topic");
    print $query->p, $query->hr, $query->p;

    # Display the context in question.  Allow the user to increase it
    # or decrease it appropriately.
    my $inc_context = ($context <= 0) ? 1 : $context*2;
    my $dec_context = ($context <= 0) ? 0 : int($context/2);
    my $inc_context_url =
	$url_builder->edit_url($line, $topic, $inc_context, "");
    my $dec_context_url =
	$url_builder->edit_url($line, $topic, $dec_context, "");
    print "Context: (" .
	$query->a({href=>"$inc_context_url"},"increase") . " | " .
	$query->a({href=>"$dec_context_url"},"decrease)");
    
    print $query->p .
	$query->pre(Codestriker::Http::Render->get_context($line, $topic,
							   $context, 1,
							   \@document)) .
							   $query->p;

    # Display the comments which have been made for this line number
    # thus far in reverse order.
    for (my $i = $#comment_linenumber; $i >= 0; $i--) {
	if ($comment_linenumber[$i] == $line) {
	    print $query->hr . "$comment_author[$i] $comment_date[$i]";
	    print $query->br . "\n";
	    print $query->pre($http_response->escapeHTML($comment_data[$i])) .
		$query->p;
	}
    }
    
    # Create a form which will allow the user to enter in some comments.
    print $query->hr, $query->p("Enter comments:"), $query->p;
    print $query->start_form();
    $query->param(-name=>'action', -value=>'submit_comment');
    print $query->hidden(-name=>'action', -default=>'submit_comment');
    print $query->hidden(-name=>'line', -default=>"$line");
    print $query->hidden(-name=>'topic', -default=>"$topic");
    print $query->hidden(-name=>'mode', -default=>"$mode");
    print $query->textarea(-name=>'comments',
			   -rows=>15,
			   -columns=>75,
			   -wrap=>'hard');

    print $query->p, $query->start_table();
    print $query->Tr($query->td("Your email address: "),
		     $query->td($query->textfield(-name=>'email',
						  -size=>50,
						  -default=>"$email",
						  -override=>1,
						  -maxlength=>100)));
    print $query->Tr($query->td("Cc: "),
		     $query->td($query->textfield(-name=>'cc',
						  -size=>50,
						  -maxlength=>150)));
    print $query->end_table(), $query->p;
    print $query->submit(-value=>'Submit');
    print $query->end_form();
}

1;
