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

# Prototypes.
sub _read_cvs_file( $$$$$ );

# If the input is valid, display the topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    # Retrieve the parameters for this action.
    my $query = $http_response->get_query();
    my $topic = $http_input->get('topic');

    # Retrieve the appropriate topic details.
    my ($document_author, $document_title, $document_bug_ids,
	$document_reviewers, $document_cc, $description,
	$topic_data, $document_creation_time, $document_modified_time,
	$topic_state, $version);
    Codestriker::Model::Topic->read($topic, \$document_author,
				    \$document_title, \$document_bug_ids,
				    \$document_reviewers, \$document_cc,
				    \$description, \$topic_data,
				    \$document_creation_time,
				    \$document_modified_time, \$topic_state,
				    \$version);

    # Dump the raw topic data as text/plain.
    print $query->header(-type=>'text/plain');
    print $topic_data;
}

1;
