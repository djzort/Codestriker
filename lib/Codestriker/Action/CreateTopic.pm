###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying the create topic form.

package Codestriker::Action::CreateTopic;

use strict;
use Codestriker::Http::Cookie;

# Prototypes.
sub process( $$$ );

# Create an appropriate form for creating a new topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    $http_response->generate_header("", "Create new topic", "", "", "", "");

    print $query->h1("Create new topic"), $query->p;
    print $query->start_multipart_form();
    $query->param(-name=>'action', -value=>'submit_topic');
    print $query->hidden(-name=>'action', -default=>'submit_topic');
    print "Topic title: ", $query->br;
    print $query->textfield(-name=>'topic_title',
			    -size=>70,
			    -maxlength=>70);
    print $query->p, "Topic description: ", $query->br;
    print $query->textarea(-name=>'topic_description',
			   -rows=>5,
			   -columns=>70,
			   -wrap=>'hard');

    # Don't wrap the topic text, in case people are cutting and pasting code
    # rather than using the file upload.
    print $query->p, "Topic text: ", $query->br;
    print $query->textarea(-name=>'topic_text',
			   -rows=>15,
			   -columns=>70);

    print $query->p, $query->start_table();
    print $query->Tr($query->td("Topic text upload: "),
		     $query->td($query->filefield(-name=>'topic_file',
						  -size=>40,
						  -maxlength=>200)));
    print $query->Tr($query->td("Bug IDs: "),
		     $query->td($query->textfield(-name=>'bug_ids',
						  -size=>30,
						  -maxlength=>50)));
    my $default_email =
	Codestriker::Http::Cookie->get_property($query, 'email');
    print $query->Tr($query->td("Your email address: "),
		     $query->td($query->textfield(-name=>'email',
						  -size=>50,
						  -default=>"$default_email",
						  -override=>1,
						  -maxlength=>80)));
    my $default_reviewers =
	Codestriker::Http::Cookie->get_property($query, 'reviewers');
    print $query->Tr($query->td("Reviewers: "),
		     $query->td($query->textfield(-name=>'reviewers',
						  -size=>50,
						  -default=>"$default_reviewers",
						  -override=>1,
						  -maxlength=>150)));
    my $default_cc =
	Codestriker::Http::Cookie->get_property($query, 'cc');
    print $query->Tr($query->td("Cc: "),
		     $query->td($query->textfield(-name=>'cc',
						  -size=>50,
						  -default=>"$default_cc",
						  -override=>1,
						  -maxlength=>150)));
    print $query->end_table();
    print $query->p, $query->submit(-value=>'submit');
    print $query->end_form();
}

1;
