###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Topic Listener to record any changes in the topic's properties or a
# comment's state.

use strict;

package Codestriker::TopicListeners::HistoryRecorder;

use Codestriker::TopicListeners::TopicListener;
use Codestriker::DB::DBI;

@Codestriker::TopicListeners::HistoryRecorder::ISA =
    ("Codestriker::TopicListeners::TopicListener");

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

    # This code is here to handle the case of a topic being created
    # in the older (pre 1.8.0) versions of codestriker. The older 
    # topics have been created without any topic history. See if 
    # topichistory row exists for the old topic, if not add it in first.

    if (Codestriker::Model::Topic::exists($topic->{topicid}))
    {
    my $dbh = Codestriker::DB::DBI->get_connection();

        my @array = $dbh->selectrow_array('SELECT COUNT(version) '. 
					  'FROM topichistory ' .
					  'WHERE ? = topicid and ? = version',
					  {},
					  $topic->{topicid},
					  $topic_orig->{version});

        my $old_topic_has_history = $array[0];

    # Release the database connection.
    Codestriker::DB::DBI->release_connection($dbh,1);

    if ( $old_topic_has_history == 0)
    {
        $self->_insert_topichistory_entry($topic_orig->{author}, $topic_orig);
    }

    $self->_insert_topichistory_entry($user, $topic);
    }
    else
    {
        # The Topic change is a topic delete, so we don't want to add a
        # history event to a topic that no longer exists. 
    }

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
    if (! defined $user || $user eq "") {
	$user = "";
    }

    $success &&= $insert->execute($topic->{topicid}, $user, $creation_ts);

    # Release the database connection.
    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;
}

# Insert a row into the commentstatehistory table.
sub _insert_commentstatehistory_entry($$$$$) {
    my ($self, $user, $comment, $metric_name, $metric_value) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    my $get_count =
	$dbh->prepare_cached('SELECT COUNT(*) FROM commentstatehistory ' .
			     'WHERE id = ?');

    my $insert =
	$dbh->prepare_cached('INSERT INTO commentstatehistory ' .
			     '(id, state, version, metric_name, metric_value, ' .
			     'modified_ts, modified_by_user) '.
			     'VALUES (?, ?, ?, ?, ?, ?, ?)');
    my $success = defined $insert && defined $get_count;
    $success &&= $get_count->execute($comment->{id});
    my ($count) = $get_count->fetchrow_array() if $success;
    $success &&= $get_count->finish();
    $success &&= $insert->execute($comment->{id}, 0, $count+1,
				  $metric_name, $metric_value,
				  $comment->{db_modified_ts}, $user);
    
    # Release the database connection.
    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;
}

# Add a new record in the commentstatehistory table.
sub comment_create($$$) {
    my ($self, $topic, $comment) = @_;

    # The author of the new comment is also the user who created it.  Need
    # to add in all the new metrics created as separate rows.
    foreach my $metric_name (keys %{$comment->{metrics}}) {
	my $metric_value = $comment->{metrics}->{$metric_name};
	$self->_insert_commentstatehistory_entry($comment->{author}, $comment,
						 $metric_name, $metric_value);
    }
    return '';    
}

# Add an updated record for this commentstate to the commentstatehistory table.
sub comment_state_change($$$$$$$) {
    my ($self, $user, $metric_name, $old_value, $new_value,
	$topic, $comment) = @_;

    $self->_insert_commentstatehistory_entry($user, $comment, $metric_name,
					     $new_value);
    return '';    
}

