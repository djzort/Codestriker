###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Topic Listener for Bugzilla. All Codestriker topic lifecycle events
# are stored into the associated Bugzilla records.

use strict;
use warnings;

package Codestriker::TopicListeners::Bugzilla;

use Codestriker::TopicListeners::TopicListener;
use Codestriker::BugDB::BugDBConnectionFactory;

our @ISA = ("Codestriker::TopicListeners::TopicListener");

sub new {
    my $type = shift;
    
    # TopicListener is parent class.
    my $self = Codestriker::TopicListeners::TopicListener->new();
    return bless $self, $type;
}

sub topic_create($$) { 
    my ($self,$topic) = @_;

    # If Codestriker is linked to a bug database, and this topic is associated
    # with some bugs, update them with an appropriate message.
    if ($topic->{bug_ids} ne "" && $Codestriker::bug_db ne "") {
	my $query = new CGI;
        my $url_builder = Codestriker::Http::UrlBuilder->new($query);
        my $topic_url =
	    $url_builder->view_url_extended($topic->{topicid}, -1, "", "", "",
					    $query->url(), 0);
        
	my $bug_db_connection =
	    Codestriker::BugDB::BugDBConnectionFactory->getBugDBConnection();
	$bug_db_connection->get_connection();
	my @ids = split /, /, $topic->{bug_ids};
        
	my $text = "Codestriker topic: $topic_url created.\n" .
	    "Author: $topic->{author}\n" .
	    "Reviewer(s): $topic->{reviewers}\n" .
	    "Title: $topic->{title}\n";
            
	for (my $i = 0; $i <= $#ids; $i++) {
	    $bug_db_connection->update_bug($ids[$i], $text);
	}
	$bug_db_connection->release_connection();
    }
    
    return '';
}

sub topic_state_change($$$) {
    my ($self,$topic,$newstate) = @_;

    # If Codestriker is linked to a bug database, and this topic is associated
    # with some bugs, update them with an appropriate message.
    if ($topic->{bug_ids} ne "" && $Codestriker::bug_db ne "") {

	my $query = new CGI;
        my $url_builder = Codestriker::Http::UrlBuilder->new($query);
        my $topic_url =
	    $url_builder->view_url_extended($topic->{topicid}, -1, "", "", "",
					    $query->url(), 0);
 	my $bug_db_connection =
	    Codestriker::BugDB::BugDBConnectionFactory->getBugDBConnection();
	$bug_db_connection->get_connection();
        
	my @ids = split /, /, $topic->{bug_ids};
                                                                    
	my $text = "Codestriker topic: $topic_url\n" .
	    "State changed to \"$newstate\" by $topic->{author}\n";
            
	for (my $i = 0; $i <= $#ids; $i++) {
	    $bug_db_connection->update_bug($ids[$i], $text);
	}
	$bug_db_connection->release_connection();
    }
    
    return '';
}

sub topic_delete($$) {
    my ($self,$topic) = @_;
    
    $self->topic_state_change($topic,"Deleted");
        
    return '';     
}

1;
