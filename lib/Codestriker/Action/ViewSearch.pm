###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying the topic search page.

package Codestriker::Action::ViewSearch;

use strict;

# Create an appropriate form for topic searching.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    $http_response->generate_header("", "Search", "", "", "", "");

    print $query->h1("Topic search"), $query->p;
    print $query->start_form();
    $query->param(-name=>'action', -value=>'submit_search');
    print $query->hidden(-name=>'action', -default=>'submit_search');
    print $query->start_table();
    print $query->Tr($query->td("Author: "),
		     $query->td($query->textfield(-name=>'sauthor',
						  -size=>50,
						  -maxlength=>100))) . "\n";
    print $query->Tr($query->td("Reviewer: "),
		     $query->td($query->textfield(-name=>'sreviewer',
						  -size=>50,
						  -maxlength=>100))) . "\n";
    print $query->Tr($query->td("Cc: "),
		     $query->td($query->textfield(-name=>'scc',
						  -size=>50,
						  -maxlength=>100))) . "\n";
    print $query->Tr($query->td("Bug ID: "),
		     $query->td($query->textfield(-name=>'sbugid',
						  -size=>50,
						  -maxlength=>100))) . "\n";
    my @states = ("Any");
    push @states, @Codestriker::topic_states;
    print $query->Tr($query->td("State: "),
		     $query->td($query->scrolling_list(-name=>'state_group',
						       -values=>\@states,
						       -default=>["Open"],
						       -size=>3,
						       -multiple=>'true')));
    print "\n";

    print $query->Tr($query->td("Contains text: "),
		     $query->td($query->textfield(-name=>'stext',
						  -size=>50,
						  -maxlength=>100))) . "\n";

    my @textwhere = ("title", "description", "comment", "body");
    print $query->Tr($query->td("&nbsp;"),
		     $query->td("in: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;" .
				$query->checkbox_group(-name=>'text_group',
						       -values=>\@textwhere,
						       -default=>["title"])));
				
    print "\n";

    print $query->end_table();
    print $query->submit(-value=>'Submit');
    print $query->end_form();
}

1;
