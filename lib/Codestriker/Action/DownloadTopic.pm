###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for downloading the raw text of a topic.

package Codestriker::Action::DownloadTopic;

use strict;

use Codestriker::Http::Render;
use Codestriker::Model::Topic;

# If the input is valid, display the topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    # Retrieve the parameters for this action.
    my $query = $http_response->get_query();
    my $topicid = $http_input->get('topic');

    my $topic = Codestriker::Model::Topic->new($topicid);

    # Dump the raw topic data as text/plain.
    print $query->header(-type=>'text/plain',
			 -attachment=>"topic${topicid}.txt");
    print $topic->{document};
}

1;
