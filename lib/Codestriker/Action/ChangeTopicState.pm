###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of changing a topic's state.

package Codestriker::Action::ChangeTopicState;

use strict;

# Attempt to change the topic's state.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $topic = $http_input->get('topic');
    my $mode = $http_input->get('mode');
    my $version = $http_input->get('version');
    my $topic_state = $http_input->get('topic_state');

    # Update the topic's state.
    my $timestamp = Codestriker->get_timestamp(time);
    Codestriker::Model::Topic->change_state($topic, $topic_state, $timestamp,
					    $version);

    # Redirect the user to the view topic page.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);
    my $redirect_url = $url_builder->view_url($topic, -1, $mode);
    print $query->redirect(-URI=>$redirect_url);
}

1;
