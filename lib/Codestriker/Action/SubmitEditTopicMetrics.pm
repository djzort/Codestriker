###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of changing the properties of a
# topic.

package Codestriker::Action::SubmitEditTopicMetrics;

use strict;

use Codestriker::Model::Topic;

# Attempt to change the topic's state, or to delete it.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $topicid = $http_input->get('topic');
    my $mode = $http_input->get('mode');
    my $version = $http_input->get('version');
    my $email = $http_input->get('email');

    my $topic = Codestriker::Model::Topic->new($topicid);    
    my $metrics = $topic->get_metrics();
    my $feedback = "";
    my @topic_metric = @{$http_input->get('topic_metric')};

    $feedback .= $metrics->verify_topic_metrics(@topic_metric);

    $metrics->set_topic_metrics(@topic_metric);

    $metrics->set_user_metric($topic->{author},
			      @{$http_input->{author_metric}});

    my @reviewer_list = $topic->get_metrics()->get_complete_list_of_topic_participants();

    # Remove the author from the list just in case somebody put themselves
    # in twice.
    @reviewer_list = grep { $_ ne $topic->{author} } @reviewer_list;

    for (my $userindex = 0; $userindex < scalar(@reviewer_list); ++$userindex) {

	if (defined($http_input->get("reviewer_metric,$userindex"))) {
	    my @usermetrics = @{$http_input->get("reviewer_metric,$userindex")};

	$feedback .= $metrics->verify_user_metrics($reviewer_list[$userindex],
						   @usermetrics);
	$metrics->set_user_metric($reviewer_list[$userindex], @usermetrics);
	}
    }
    
    my @author_metrics = @{$http_input->get('author_metric')};
    $feedback .= $metrics->verify_user_metrics($topic->{author},
					       @author_metrics);
    $metrics->set_user_metric($topic->{author}, @author_metrics);
    $metrics->store();

    if ( $feedback eq "")
    {
        $feedback = "Topic metrics successfully updated.";
    }

    # The feedback var is not html escaped in the template, so it must be done directly
    # with HTML::Entities::encode if needed.    
    $http_input->{feedback} = $feedback;

    # Go to the view topic metrics screen.
    Codestriker::Action::ViewTopicInfo->process($http_input, $http_response);
}

1;
