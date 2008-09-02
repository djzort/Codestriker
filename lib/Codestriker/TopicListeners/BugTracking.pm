###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Topic Listener for a bug-tracking system, such as Bugzilla or Flyspray.
# All Codestriker topic lifecycle events are stored into the bug-tracking
# system for the record linked to the Codestriker topic.

use strict;

package Codestriker::TopicListeners::BugTracking;

use Codestriker::TopicListeners::TopicListener;
use Codestriker::BugDB::BugDBConnectionFactory;

@Codestriker::TopicListeners::BugTracking::ISA = ("Codestriker::TopicListeners::TopicListener");

sub new {
    my $type = shift;
    
    # TopicListener is parent class.
    my $self = Codestriker::TopicListeners::TopicListener->new();
    return bless $self, $type;
}

# Check that the nominated bugids exist in the bug database.
sub topic_pre_create($$) { 
    my ($self, $user, $topic_title, $topic_description, $bug_ids,
	$reviewers, $cc, $repository_url, $projectid) = @_;

    my $feedback = '';
    if ($bug_ids ne '') {
	my @bug_ids = split /, /, $bug_ids;
	my $bug_db_connection =
	    Codestriker::BugDB::BugDBConnectionFactory->getBugDBConnection();
	foreach my $bug_id (@bug_ids) {
	    if (!$bug_db_connection->bugid_exists($bug_id)) {
		$feedback .= "Bug ID $bug_id does not exist.\n";
	    }
	}
	$bug_db_connection->release_connection();
    }

    return $feedback;    
}

sub topic_create($$) { 
    my ($self, $topic) = @_;

    # If Codestriker is linked to a bug database, and this topic is associated
    # with some bugs, update them with an appropriate message.
    if ($topic->{bug_ids} ne "" && $Codestriker::bug_db ne "") {
	my $query = new CGI;
        my $url_builder = Codestriker::Http::UrlBuilder->new($query);
        my $topic_url =
	    $url_builder->view_url(topicid => $topic->{topicid},
	                           projectid => $topic->{project_id});
        
	my $bug_db_connection =
	    Codestriker::BugDB::BugDBConnectionFactory->getBugDBConnection();
	my @ids = split /, /, $topic->{bug_ids};
        
	my $text = "Codestriker topic: $topic_url created.\n" .
	    "Author: $topic->{author}\n" .
	    "Reviewer(s): $topic->{reviewers}\n" .
            "Title: $topic->{title}\n" .
            "Description:\n" . "$topic->{description}\n"; 
            
	for (my $i = 0; $i <= $#ids; $i++) {
	    $bug_db_connection->update_bug($ids[$i], $text, $topic_url,
					   $topic->{topic_state});
	}
	$bug_db_connection->release_connection();
    }
    
    return '';
}

# If the bugids have been changed, make sure they exist in the bug database.
sub topic_pre_changed($$$) {
    my ($self, $user, $topic_orig, $topic) = @_;

    my $feedback = '';
    if ($topic_orig->{bug_ids} ne $topic->{bug_ids}) {
	# Make sure that the new bug IDs specified are valid, if they have
	# changed.
	my @bug_ids = split /, /, $topic->{bug_ids};
	my $bug_db_connection =
	    Codestriker::BugDB::BugDBConnectionFactory->getBugDBConnection();
	foreach my $bug_id (@bug_ids) {
	    if (!$bug_db_connection->bugid_exists($bug_id)) {
		$feedback .= "Bug ID $bug_id does not exist.\n";
	    }
	}
	$bug_db_connection->release_connection();
    }
    
    return $feedback;
}


sub topic_changed($$$$) {
    my ($self, $user, $topic_orig, $topic) = @_;

    # If Codestriker is linked to a bug database, and this topic is associated
    # with some bugs, update them with an appropriate message.
    if ($topic->{bug_ids} ne "" && $Codestriker::bug_db ne "" &&
	$topic_orig->{topic_state} ne $topic->{topic_state}) {

	my $newstate = $topic->{topic_state};
	my $query = new CGI;
        my $url_builder = Codestriker::Http::UrlBuilder->new($query);
        my $topic_url = $url_builder->view_url(topicid => $topic->{topicid}, projectid => $topic->{project_id});
 	my $bug_db_connection =
	    Codestriker::BugDB::BugDBConnectionFactory->getBugDBConnection();
        
	my @ids = split /, /, $topic->{bug_ids};
                                                                    
	my $text = "Codestriker topic: $topic_url\n" .
	    "State changed to \"$newstate\" by $user\n";
            
	for (my $i = 0; $i <= $#ids; $i++) {
	    $bug_db_connection->update_bug($ids[$i], $text, $topic_url, $topic->{topic_state});
	}
	$bug_db_connection->release_connection();
    }
    
    return '';
}

1;
