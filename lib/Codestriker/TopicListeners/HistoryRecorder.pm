###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Topic Listener to record any changes in the topic's properties or a
# comment's state.

use strict;
use warnings;

package Codestriker::TopicListeners::HistoryRecorder;

use Codestriker::TopicListeners::TopicListener;
use Codestriker::DB::DBI;

our @ISA = ("Codestriker::TopicListeners::TopicListener");

sub new {
    my $type = shift;
    
    # TopicListener is parent class.
    my $self = Codestriker::TopicListeners::TopicListener->new();
    return bless $self, $type;
}

# Insert a row into the topichistory table.
sub _insert_topichistory_entry($$$) {
    my ($self, $user, $topic) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    my $insert =
	$dbh->prepare_cached('INSERT INTO topichistory ' .
			     '(topicid, author, title, ' .
			     'description, state, modified_ts, version, ' .
			     'repository, projectid, reviewers, ' .
			     'cc, modified_by_user) ' .
			     'VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    my $success = defined $insert;
    $success &&= $insert->execute($topic->{topicid}, $topic->{author},
				  $topic->{title}, $topic->{description},
				  $topic->{topic_state_id},
				  $topic->{modified_ts}, $topic->{version},
				  $topic->{repository}, $topic->{project_id},
				  $topic->{reviewers}, $topic->{cc}, $user);

    # Release the database connection.
    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;
}

# Create a new record in the topichistory table.
sub topic_create($$) { 
    my ($self, $topic) = @_;

    # The author of the topic is the user who created the topic.
    $self->_insert_topichistory_entry($topic->{author}, $topic);

    return '';
}

# Add an updated record for this topic to the topichistory table.
sub topic_changed($$$$) {
    my ($self, $user, $topic_orig, $topic) = @_;

    $self->_insert_topichistory_entry($user, $topic);

    return '';
}

# Add a record to the topicviewhistory table to indicate the user has
# viewed the specified topic.
sub topic_viewed($$$) {
    my ($self, $user, $topic) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    my $insert =
	$dbh->prepare_cached('INSERT INTO topicviewhistory ' .
			     '(topicid, email, creation_ts) ' .
			     'VALUES (?, ?, ?)');
    my $success = defined $insert;
    my $creation_ts = Codestriker->get_timestamp(time);
    $success &&= $insert->execute($topic->{topicid}, $user, $creation_ts);

    # Release the database connection.
    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;
}

# Insert a row into the commentstatehistory table.
sub _insert_commentstatehistory_entry($$$) {
    my ($self, $user, $comment) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    my $insert =
	$dbh->prepare_cached('INSERT INTO commentstatehistory ' .
			     '(id, state, version, ' .
			     'modified_ts, modified_by_user) '.
			     'VALUES (?, ?, ?, ?, ?)');
    my $success = defined $insert;
    $success &&= $insert->execute($comment->{id}, $comment->{state},
				  $comment->{version}, $comment->{modified_ts},
				  $user);
    

    # Release the database connection.
    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;
}

# Add a new record in the commentstatehistory table.
sub comment_create($$$) {
    my ($self, $topic, $comment) = @_;

    # The author of the new comment is also the user who created it.
    $self->_insert_commentstatehistory_entry($comment->{author}, $comment);
    return '';    
}

# Add an updated record for this commentstate to the commentstatehistory table.
sub comment_state_change($$$$$) {
    my ($self, $user, $old_state_id, $topic, $comment) = @_;

    $self->_insert_commentstatehistory_entry($user, $comment);
    return '';    
}

