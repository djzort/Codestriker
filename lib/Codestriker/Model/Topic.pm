###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling topic data.

package Codestriker::Model::Topic;

use strict;

use Codestriker::DB::DBI;
use Codestriker::Model::File;
use Codestriker::Model::Metrics;

sub new {
    my ($class, $topicid) = @_;
    my $self = {};
        
    $self->{topicid} = 0;
    $self->{author} = "";
    $self->{title} = "";
    $self->{bug_ids} = "";
    $self->{reviewers} = "";
    $self->{cc} = "";
    $self->{description} = "";
    $self->{document} = "";
    $self->{creation_ts} = "";
    $self->{modified_ts} = "";
    $self->{topic_state} = "";
    $self->{topic_state_id} = 0;
    $self->{version} = 0;
    $self->{start_tag} = "";
    $self->{end_tag} = "";
    $self->{module} = "";
    $self->{repository} = "";
    $self->{project_id} = "";
    $self->{project_name} = "";
    $self->{obsoleted_topics} = [];
    $self->{obsoleted_by} = [];
    $self->{comments} = [];
    $self->{metrics} = Codestriker::Model::Metrics->new($topicid);

    bless $self, $class;

    if (defined($topicid)) {
	$self->read($topicid);
    }
   
    return $self;
}

# Delete the specified participant type from the topic.
sub _delete_participants($$$) {
    my ($self, $dbh, $type) = @_;

    my $delete_participants =
	$dbh->prepare_cached('DELETE FROM participant ' .
			     'WHERE topicid = ? AND type = ?');
    my $success = defined $delete_participants;

    $success &&= $delete_participants->execute($self->{topicid}, $type);
    return $success;
}

# Insert the specified participants into the topic.
sub _insert_participants($$$$$) {
    my ($self, $dbh, $type, $participants, $timestamp) = @_;

    my $insert_participant =
	$dbh->prepare_cached('INSERT INTO participant (email, topicid, type,' .
			     'state, modified_ts, version) ' .
			     'VALUES (?, ?, ?, ?, ?, ?)');
    my $success = defined $insert_participant;

    my @participants = split /, /, $participants;
    for (my $i = 0; $i <= $#participants; $i++) {
	$success &&= $insert_participant->execute($participants[$i],
						  $self->{topicid}, $type, 0,
						  $timestamp, 0);
    }
    
    return $success;
}

# Delete the bugids associated with a particular topic.
sub _delete_bug_ids($$) {
    my ($self, $dbh) = @_;

    my $delete_topicbug =
	$dbh->prepare_cached('DELETE FROM topicbug WHERE topicid = ?');
    my $success = defined $delete_topicbug;

    $success &&= $delete_topicbug->execute($self->{topicid});
    return $success;
}

# Insert the comma-separated list of bug_ids into the topic.
sub _insert_bug_ids($$$) {
    my ($self, $dbh, $bug_ids) = @_;

    my $insert_bugs =
	$dbh->prepare_cached('INSERT INTO topicbug (topicid, bugid) ' .
			     'VALUES (?, ?)');
    my $success = defined $insert_bugs;

    my @bug_ids = split /, /, $bug_ids;
    for (my $i = 0; $i <= $#bug_ids; $i++) {
	$success &&= $insert_bugs->execute($self->{topicid}, $bug_ids[$i]);
    }

    return $success;
}

# Create a new topic with all of the specified properties.
sub create($$$$$$$$$$$$) {
    my ($self, $topicid, $author, $title, $bug_ids, $reviewers, $cc,
	$description, $document, $start_tag, $end_tag, $module,
	$repository, $projectid, $deltas_ref, $obsoleted_topics) = @_;

    my $timestamp = Codestriker->get_timestamp(time);        
        
    $self->{topicid} = $topicid;
    $self->{author} = $author;
    $self->{title} = $title;
    $self->{bug_ids} = $bug_ids;
    $self->{reviewers} = $reviewers;
    $self->{cc} = $cc;
    $self->{description} = $description;
    $self->{document} = $document;
    $self->{creation_ts} = $timestamp;
    $self->{modified_ts} = $timestamp;
    $self->{topic_state} = 0;
    $self->{topic_state_id} = 0;
    $self->{project_id} = $projectid;
    $self->{version} = 0;
    $self->{start_tag} = $start_tag;
    $self->{end_tag} = $end_tag;
    $self->{module} = $module;
    $self->{repository} = $repository;
    $self->{metrics} = Codestriker::Model::Metrics->new($topicid);
    $self->{obsoleted_topics} = [];
    $self->{obsoleted_by} = [];

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Create the prepared statements.
    my $insert_topic =
	$dbh->prepare_cached('INSERT INTO topic (id, author, title, ' .
			     'description, document, state, creation_ts, ' .
			     'modified_ts, version, start_tag, end_tag, ' .
			     'module, repository, projectid) ' .
			     'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    my $success = defined $insert_topic;

    # Create all of the necessary rows.  It is assumed state 0 is the initial
    # state.
    $success &&= $insert_topic->execute($topicid, $author, $title,
					$description, $document, 0,
					$timestamp, $timestamp, 0,
					$start_tag, $end_tag, $module,
					$repository, $projectid);
	
    # Insert the associated bug records.
    $success &&= $self->_insert_bug_ids($dbh, $bug_ids);

    # Insert the reviewers and cc participants.
    $success &&=
	$self->_insert_participants($dbh,
				    $Codestriker::PARTICIPANT_REVIEWER,
				    $reviewers, $timestamp);
    $success &&=
	$self->_insert_participants($dbh,
				    $Codestriker::PARTICIPANT_CC,
				    $cc, $timestamp);

    # Create the appropriate delta rows.
    $success &&= Codestriker::Model::File->create($dbh, $topicid, $deltas_ref);

    # Create any obsolete records, if any.
    if (defined $obsoleted_topics && $obsoleted_topics ne '') {
	my $insert_obsolete_topic =
	    $dbh->prepare_cached('INSERT INTO topicobsolete ' .
				 '(topicid, obsoleted_by) ' .
				 'VALUES (?, ?)');
	my $success = defined $insert_obsolete_topic;
	my @data = split ',', $obsoleted_topics;
	my @obsoleted = ();
	for (my $i = 0; $success && $i <= $#data; $i+=2) {
	    my $obsolete_topic_id = $data[$i];
	    my $obsolete_topic_version = $data[$i+1];
	    $success &&=
		$insert_obsolete_topic->execute($obsolete_topic_id,
						$topicid);
	    push @obsoleted, $obsolete_topic_id if $success;
	}
	$self->{obsoleted_topics} = \@obsoleted;
    }
    
    Codestriker::DB::DBI->release_connection($dbh, $success);

    die $dbh->errstr unless $success;
}

# Read the contents of a specific topic, and return the results in the
# provided reference variables.
sub read($$) {
    my ($self, $topicid) = @_;
    
    $self->{topicid} = $topicid;    

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Setup the prepared statements.
    my $select_topic = $dbh->prepare_cached('SELECT topic.id, topic.author, ' .
					    'topic.title, ' .
					    'topic.description, ' .
					    'topic.document, topic.state, ' .
					    'topic.creation_ts, ' .
					    'topic.modified_ts, ' .
					    'topic.version, ' .
					    'topic.start_tag, ' .
					    'topic.end_tag, ' .
					    'topic.module, ' .
					    'topic.repository, ' .
					    'project.id, project.name ' .
					    'FROM topic, project ' .
					    'WHERE topic.id = ? AND ' .
					    'topic.projectid = project.id');
    my $select_bugs =
	$dbh->prepare_cached('SELECT bugid FROM topicbug WHERE topicid = ?');
    my $select_participants =
	$dbh->prepare_cached('SELECT type, email FROM participant ' .
			     'WHERE topicid = ?');
    my $select_obsoleted_by =
	$dbh->prepare_cached('SELECT obsoleted_by FROM topicobsolete ' .
			     'WHERE topicid = ?');
    my $select_topics_obsoleted =
	$dbh->prepare_cached('SELECT topicid FROM topicobsolete ' .
			     'WHERE obsoleted_by = ?');

    my $success = defined $select_topic && defined $select_bugs &&
	defined $select_participants && defined $select_obsoleted_by &&
	defined $select_topics_obsoleted;
    my $rc = $Codestriker::OK;

    # Retrieve the topic information.
    $success &&= $select_topic->execute($topicid);

    my ($id, $author, $title, $description, $document, $state,
	$creationtime, $modifiedtime, $version, $start_tag, $end_tag,
	$module, $repository, $projectid, $projectname);

    if ($success) {
	($id, $author, $title, $description, $document, $state,
	 $creationtime, $modifiedtime, $version, $start_tag, $end_tag,
	 $module, $repository, $projectid, $projectname)
	    = $select_topic->fetchrow_array();
	$select_topic->finish();

	if (!defined $id) {
	    $success = 0;
	    $rc = $Codestriker::INVALID_TOPIC;
	}
    }

    # Retrieve the bug ids relating to this topic.
    my @bugs = ();
    $success &&= $select_bugs->execute($topicid);
    if ($success) {
	my @data;
	while (@data = $select_bugs->fetchrow_array()) {
	    push @bugs, $data[0];
	}
	$select_bugs->finish();
    }

    # Retrieve the participants in this review.
    my @reviewers = ();
    my @cc = ();
    $success &&= $select_participants->execute($topicid);
    if ($success) {
	while (my @data = $select_participants->fetchrow_array()) {
	    if ($data[0] == 0) {
		push @reviewers, $data[1];
	    } else {
		push @cc, $data[1];
	    }
	}
	$select_participants->finish();
    }

    # Retrieve the topics obsoleted by this topic.
    $success &&= $select_topics_obsoleted->execute($topicid);
    my @obsoleted_topics = ();
    if ($success) {
	while (my ($id) = $select_topics_obsoleted->fetchrow_array()) {
	    push @obsoleted_topics, $id;
	}
	$select_topics_obsoleted->finish();
    }

    # Retrieve the topics that have obsoleted this topic.
    $success &&= $select_obsoleted_by->execute($topicid);
    my @obsoleted_by = ();
    if ($success) {
	while (my ($id) = $select_obsoleted_by->fetchrow_array()) {
	    push @obsoleted_by, $id;
	}
	$select_obsoleted_by->finish();
    }

    # Close the connection, and check for any database errors.
    Codestriker::DB::DBI->release_connection($dbh, $success);

    # Store the data into the referenced variables if the operation was
    # successful.
    if ($success) {
	$self->{author} = $author;
	$self->{title} = $title;
	$self->{bug_ids} = join ', ', @bugs;
	$self->{reviewers} = join ', ', @reviewers;
	$self->{cc} = join ', ', @cc;
	$self->{description} = $description;
	$self->{document} = $document;
	$self->{creation_ts} = $creationtime;
	$self->{modified_ts} = $modifiedtime;
	$self->{topic_state} = $Codestriker::topic_states[$state];
	$self->{topic_state_id} = $state;
	$self->{project_id} = $projectid;
	$self->{project_name} = $projectname;
	$self->{start_tag} = $start_tag;
	$self->{end_tag} = $end_tag;
	$self->{module} = $module;
	$self->{version} = $version;
        $self->{metrics} = Codestriker::Model::Metrics->new($topicid);
	$self->{obsoleted_topics} = \@obsoleted_topics;
	$self->{obsoleted_by} = \@obsoleted_by;
	
	# Set the repository to the default system value if it is not defined.
	if (!defined $repository || $repository eq "") {
	    $self->{repository} = $Codestriker::default_repository;
	} else {
	    $self->{repository} = $repository;
	}
    }

    return $success ? $Codestriker::OK : $rc;
}

# Reads from the db if needed, and returns the list of comments for
# this topic. If the list of comments have already been returned, the
# function will skip the db call, and just return the list from
# memory.
sub read_comments {
    my ($self) = shift;

    if (scalar(@{$self->{comments}}) == 0) {
	my @comments = Codestriker::Model::Comment->read_all_comments_for_topic($self->{topicid});
    
	$self->{comments} = \@comments;
    }

    return @{$self->{comments}};
}


# Retrieve the changed files which are a part of this review. It will only pull them
# from the database once.
sub get_filestable
{
    my ($self,$filenames, $revisions, $offsets, $binary, $numchanges) = @_;

    if (exists ($self->{filetable})) {

    	( $filenames, $revisions, $offsets,$binary, $numchanges ) = @{$self->{filetable}};
    }
    else {

        Codestriker::Model::File->get_filetable($self->{topicid},
    		    $filenames,
                    $revisions,
                    $offsets,
                    $binary,
                    $numchanges);

        $self->{filetable} = [ 
    		    $filenames,
                    $revisions,
                    $offsets,
                    $binary,
                    $numchanges ];

    }

}



# Determine if the specified topic id exists in the table or not.
sub exists($) {
    my ($topicid) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Prepare the statement and execute it.
    my $select_topic = $dbh->prepare_cached('SELECT COUNT(*) FROM topic ' .
					    'WHERE id = ?');
    my $success = defined $select_topic;
    $success &&= $select_topic->execute($topicid);

    my $count;
    if ($success) {
	($count) = $select_topic->fetchrow_array();
	$select_topic->finish();
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;

    return $count;
}

# This function returns the metrics objects that are part of the topic.
sub get_metrics {
    my ($self) = @_;

    return $self->{metrics};
}

# Returns the size of the topic text in lines. If the topic is a diff topic
# it attempts to only count the lines that have changed, and not count the
# context around the lines.
sub get_topic_size_in_lines {

    my ($self) = @_;

    my @deltas = Codestriker::Model::Delta->get_delta_set($self->{topicid}, -1);

    my $line_count = 0;

    foreach my $delta (@deltas)
    {
        my @document = split /\n/, $delta->{text};

        $line_count += scalar( grep /^[+-][^+-][^+-]/, @document );
    }

    return $line_count;
}


# This function is used to create a new topic id. The function insures 
# that the new topic id is difficult to guess, and is not taken in the 
# database already.
sub create_new_topicid {
    # For "hysterical" reasons, the topic id is randomly generated.  Seed the
    # generator based on the time and the pid.  Keep searching until we find
    # a free topicid.  In 99% of the time, we will get a new one first time.
    srand(time() ^ ($$ + ($$ << 15)));
    my $topicid;
    do {
	$topicid = int rand(10000000);
    } while (Codestriker::Model::Topic::exists($topicid));
    
    return $topicid;
}

# Everytime a topic is stored the version number is incremented. When
# a page is created it includes the version number of the topic used
# to create the page. The user posts information back to server to
# change, the version information needs to be checked to make sure
# somebody else has not modified the server.
sub check_for_stale($$) {
    my ($self, $version) = @_;

    return $self->{version} ne $version;
}

# Update the state of the specified topic. 
sub change_state($$) {
    my ($self, $new_state) = @_;
    
    my $modified_ts = Codestriker->get_timestamp(time);
    
    # Map the new state to its number.
    my $new_stateid;
    for ($new_stateid = 0; $new_stateid <= $#Codestriker::topic_states;
	 $new_stateid++) {
	last if ($Codestriker::topic_states[$new_stateid] eq $new_state);
    }
    if ($new_stateid > $#Codestriker::topic_states) {
	die "Unable to change topic to invalid state: \"$new_state\"";
    }
    
    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();
    
    # Check that the version reflects the current version in the DB.  
    my $select_topic =
	$dbh->prepare_cached('SELECT version ' .
			     'FROM topic WHERE id = ?');
    my $update_topic =
	$dbh->prepare_cached('UPDATE topic SET version = ?, state = ?, ' .
			     'modified_ts = ? WHERE id = ?');
    my $success = defined $select_topic && defined $update_topic;
    my $rc = $Codestriker::OK;
    
    # Retrieve the current topic data.
    $success &&= $select_topic->execute($self->{topicid});
    
    # Make sure that the topic still exists, and is therefore valid.
    my ($current_version);
    if ($success && ! (($current_version) =
		       $select_topic->fetchrow_array())) {
	# Invalid topic id.
	$success = 0;
	$rc = $Codestriker::INVALID_TOPIC;
    }
    $success &&= $select_topic->finish();
    
    # Check the version number.
    if ($self->{version} != $current_version) {
	$success = 0;
	$rc = $Codestriker::STALE_VERSION;
    }
    
    # If the state hasn't changed, don't do anything, otherwise update the
    # topic.
    if ($new_state ne $self->{topic_state}) {
    	$self->{version} = $self->{version} + 1;
	$success &&= $update_topic->execute($self->{version}, $new_stateid,
					    $modified_ts,
					    $self->{topicid});
    }
    
    $self->{modified_ts} = $modified_ts;
    $self->{topic_state} = $new_state;
    
    Codestriker::DB::DBI->release_connection($dbh, $success);
    return $rc;
}

# Update the properties of the specified topic. This is not implemented
# very efficiently, however it is not expected to be called very often.
sub update($$$$$$$$$$) {
    my ($self, $new_title, $new_author, $new_reviewers, $new_cc,
	$new_repository, $new_bug_ids, $new_projectid, $new_description,
	$new_state) = @_;

    # First check that the version matches the current topic version in the
    # database.
    my $dbh = Codestriker::DB::DBI->get_connection();
    my $select_topic =
	$dbh->prepare_cached('SELECT version ' .
			     'FROM topic WHERE id = ?');
    my $success = defined $select_topic;
    my $rc = $Codestriker::OK;

    # Make sure that the topic still exists, and is therefore valid.
    $success &&= $select_topic->execute($self->{topicid});
    my $current_version;
    if ($success && 
	! (($current_version) =
	   $select_topic->fetchrow_array())) {
	# Invalid topic id.
	$success = 0;
	$rc = $Codestriker::INVALID_TOPIC;
    }
    $success &&= $select_topic->finish();

    # Check the version number.
    if ($success && $self->{version} != $current_version) {
	$success = 0;
	$rc = $Codestriker::STALE_VERSION;
    }

    # Get the modified date to the current time.
    my $modified_ts = Codestriker->get_timestamp(time);

    # Map the new state to its number.
    my $new_stateid;
    for ($new_stateid = 0; $new_stateid <= $#Codestriker::topic_states;
	 $new_stateid++) {
	last if ($Codestriker::topic_states[$new_stateid] eq $new_state);
    }
    if ($new_stateid > $#Codestriker::topic_states) {
	die "Unable to change topic to invalid state: \"$new_state\"";
    }

    # Update the topic object's properties.
    $self->{title} = $new_title;
    $self->{author} = $new_author;
    $self->{repository} = $new_repository;
    $self->{project_id} = $new_projectid;
    $self->{description} = $new_description;
    $self->{modified_ts} = $modified_ts;
    $self->{topic_state} = $new_state;
    $self->{topic_state_id} = $new_stateid;

    # Now update the database with the new properties. 
    my $update_topic =
	$dbh->prepare_cached('UPDATE topic SET version = ?, state = ?, ' .
			     'modified_ts = ?, ' .
			     'title = ?, author = ?, ' .
			     'repository = ?, projectid = ?, ' .
			     'description = ? WHERE id = ?');
    $success &&= defined $update_topic;

    # If the state hasn't changed, don't do anything, otherwise update the
    # topic.
    if ($success) {
    	$self->{version} = $self->{version} + 1;
	$success &&= $update_topic->execute($self->{version}, $new_stateid,
					    $modified_ts,
					    $new_title, $new_author,
					    $new_repository, $new_projectid,
					    $new_description,
					    $self->{topicid});
    }

    # Now delete all bugs associated with this topic, and recreate them again
    # if they have changed.
    if ($success && $self->{bug_ids} ne $new_bug_ids) {
	$success &&= $self->_delete_bug_ids($dbh);
	$success &&= $self->_insert_bug_ids($dbh, $new_bug_ids);
	$self->{bug_ids} = $new_bug_ids;
    }

    # Now delete all reviewers associated with this topic, and recreate
    # them again, if they have changed.
    if ($success && $self->{reviewers} ne $new_reviewers) {
	$success &&=
	    $self->_delete_participants($dbh,
					$Codestriker::PARTICIPANT_REVIEWER);
	$success &&=
	    $self->_insert_participants($dbh,
					$Codestriker::PARTICIPANT_REVIEWER,
					$new_reviewers, $modified_ts);
	$self->{reviewers} = $new_reviewers;
    }

    # Now delete all CCs associated with this topic, and recreate
    # them again, if they have changed.
    if ($success && $self->{cc} ne $new_cc) {
	$success &&=
	    $self->_delete_participants($dbh, $Codestriker::PARTICIPANT_CC);
	$success &&=
	    $self->_insert_participants($dbh, $Codestriker::PARTICIPANT_CC,
					$new_cc, $modified_ts);
	$self->{cc} = $new_cc;
    }
	
    Codestriker::DB::DBI->release_connection($dbh, $success);

    if ($success == 0 && $rc == $Codestriker::OK) {
	# Unexpected DB error.
	die $dbh->errstr;
    }

    return $rc;
}

# Return back the list of topics which match the specified parameters.
sub query($$$$$$$$$$$$$$\@\@\@) {
    my ($type, $sauthor, $sreviewer, $scc, $sbugid, $sstate, $sproject, $stext,
	$stitle, $sdescription, $scomments, $sbody, $sfilename, $sort_order,
        $topic_query_results_ref) = @_;

    # Obtain a database connection.
    my $database = Codestriker::DB::Database->get_database();
    my $dbh = $database->get_connection();

    # If there are wildcards in the author, reviewer, or CC fields,
    # replace them with the appropriate SQL wildcards.
    $sauthor =~ s/\*/%/g if $sauthor ne "";
    $sreviewer =~ s/\*/%/g if $sreviewer ne "";
    $scc =~ s/\*/%/g if $scc ne "";

    # Automatically surround the search term term in wildcards, and replace
    # any wildcards appropriately.
    if ($stext ne "") {
	$stext =~ s/\*/%/g;
	if (! ($stext =~ /^%/o) ) {
	    $stext = "%${stext}";
	}
	if (! ($stext =~ /%$/o) ) {
	    $stext = "${stext}%";
	}
    }

    # Build up the query conditions.
    my $author_part = $sauthor eq "" ? "" :
	$database->case_insensitive_like("topic.author", $sauthor);
    my $reviewer_part = $sreviewer eq "" ? "" :
	($database->case_insensitive_like("participant.email", $sreviewer) .
	 " AND type = $Codestriker::PARTICIPANT_REVIEWER");
    my $cc_part = $scc eq "" ? "" :
	($database->case_insensitive_like("participant.email", $scc) .
	 " AND type = $Codestriker::PARTICIPANT_CC");
    my $bugid_part = $sbugid eq "" ? "" :
	("topicbug.bugid = " . $dbh->quote($sbugid));

    # Build up the state condition.
    my $state_part = "";
    if ($sstate ne "") {
	$state_part = "topic.state IN ($sstate)";
    }

    # Build up the project condition.
    my $project_part = "";
    if ($sproject ne "") {
	$project_part = "topic.projectid IN ($sproject)";
    }

    my $text_title_part =
	$database->case_insensitive_like("topic.title", $stext);
    my $text_description_part =
	$database->case_insensitive_like("topic.description", $stext);
    my $text_body_part = 
	$database->case_insensitive_like("topic.document", $stext);
    my $text_filename_part =
	$database->case_insensitive_like("topicfile.filename", $stext);
    my $text_comment_part =
	$database->case_insensitive_like("commentdata.commentfield", $stext);

    # Build up the base query.
    my $query =
	"SELECT topic.id, topic.title, topic.description, " .
	"topic.author, topic.creation_ts, " .
	"topic.state, topicbug.bugid, participant.email, participant.type, " .
	"topic.version ";

    # Since Oracle < 9i can't handle LEFT OUTER JOIN, determine what tables
    # are required in this query and add them in.
    my $using_oracle = $Codestriker::db =~ /^DBI:Oracle/i;
    if ($using_oracle) {
	my @fromlist = ("topic", "topicbug", "participant");
	if ($stext ne "" && $scomments) {
	    push @fromlist, "commentstate";
	    push @fromlist, "commentdata";
	}
	if ($stext ne "" && $sfilename) {
	    push @fromlist, "topicfile";
	}
	$query .= "FROM " . (join ', ', @fromlist) . " WHERE ";
    }
    else {
	$query .= "FROM topic ";
    }

    # Add the join to topicbug and participant.
    if ($using_oracle) {
	$query .= "topic.id = topicbug.topicid(+) AND " .
	    "topic.id = participant.topicid(+) ";
    }
    else {
	$query .= "LEFT OUTER JOIN topicbug ON topic.id = topicbug.topicid " .
	"LEFT OUTER JOIN participant ON topic.id = participant.topicid ";
    }

    # Join with the comment table if required - GACK!
    if ($stext ne "" && $scomments) {
	if ($using_oracle) {
	    $query .=
		' AND topic.id = commentstate.topicid(+) AND '.
		'commentstate.id = commentdata.commentstateid(+) ';
	}
	else {
	    $query .= 
		'LEFT OUTER JOIN commentstate ON ' .
		'topic.id = commentstate.topicid '.
		'LEFT OUTER JOIN commentdata ON ' .
		'commentstate.id = commentdata.commentstateid ';
	}
    }

    # Join with the file table if required.
    if ($stext ne "" && $sfilename) {
	if ($using_oracle) {
	    $query .= ' AND topic.id = topicfile.topicid(+) ';
	}
	else {
	    $query .= 'LEFT OUTER JOIN topicfile ON ' .
		'topicfile.topicid = topic.id ';
	}
    }

    # Combine the "AND" conditions together.  Note for Oracle, the 'WHERE'
    # keyword has already been used.
    my $first_condition = $using_oracle ? 0 : 1;
    $query = _add_condition($query, $author_part, \$first_condition);
    $query = _add_condition($query, $reviewer_part, \$first_condition);
    $query = _add_condition($query, $cc_part, $scc, \$first_condition);
    $query = _add_condition($query, $bugid_part, $sbugid,
			    \$first_condition);

    # Handle the state set.
    if ($state_part ne "") {
	$query = _add_condition($query, $state_part, \$first_condition);
    }

    # Handle the project set.
    if ($project_part ne "") {
	$query = _add_condition($query, $project_part, \$first_condition);
    }

    # Handle the text searching part, which is a series of ORs.
    if ($stext ne "") {
	my @text_cond = ();
	
	push @text_cond, $text_title_part if $stitle;
	push @text_cond, $text_description_part if $sdescription;
	push @text_cond, $text_body_part if $sbody;
	push @text_cond, $text_filename_part if $sfilename;
	push @text_cond, $text_comment_part if $scomments;

	if ($#text_cond >= 0) {
	    my $cond = join  ' OR ', @text_cond;
	    $query = _add_condition($query, $cond, \$first_condition);
	}
    }

    # Order the result by the creation date field.
    if (scalar( @$sort_order ) == 0) {
        # no sort order, defaults to topic creation.
    $query .= " ORDER BY topic.creation_ts ";
    }
    else {

        my @sort_terms;

        foreach my $sortItem (@$sort_order) {
            
            if ($sortItem eq "+title") {
                push @sort_terms, "topic.title";
            }
            elsif ($sortItem eq "-title") {
                push @sort_terms, "topic.title DESC";
            }
            elsif ($sortItem eq "+author") {
                push @sort_terms, "topic.author ";
            }
            elsif ($sortItem eq "-author") {
                push @sort_terms, "topic.author DESC";
            }
            elsif ($sortItem eq "+created") {
                push @sort_terms, "topic.creation_ts ";
            }
            elsif ($sortItem eq "-created") {
                push @sort_terms, "topic.creation_ts DESC";
            }
            elsif ($sortItem eq "+state") {
                push @sort_terms, "topic.state ";
            }
            elsif ($sortItem eq "-state") {
                push @sort_terms, "topic.state DESC";
            }
            else {
                die "unknown sort key $sortItem";
            }
        }

        $query .= " ORDER BY " . join(',',@sort_terms) . " ";
    }

    my $select_topic = $dbh->prepare_cached($query);
    my $success = defined $select_topic;
    $success &&= $select_topic->execute();
    if ($success) {
	my ($id, $title, $author, $description, $creation_ts, $state, $bugid,
	    $email, $type, $version);
              
	while (($id, $title, $description, $author, $creation_ts, $state,
		$bugid, $email, $type, $version) =
	       $select_topic->fetchrow_array()) {
            
            my $topic_query_row = {
                id => $id,
                title => $title,
                description => $description,
                author => $author,
                ts => $creation_ts,
                state => $state,
                bugid => $bugid,
                email => $email,
                type => $type,
                version => $version,
            };

            push @$topic_query_results_ref, $topic_query_row;
	}
	$select_topic->finish();
    }

    # get the visited flag and the comment state metric.
    my $comment_metric_counts = [];
    my $lastid;

    foreach my $topicrow (@$topic_query_results_ref) {
        # If they configured the comment metrics to be on the main
        # page then do the queries here. Because we have a row per
        # topic per reviewer, it will make the page load faster if the
        # query is only done once per topic.
        if ( !defined($lastid) || $topicrow->{id} ne $lastid ) {
            $comment_metric_counts = [];
            $lastid = $topicrow->{id};

            foreach my $comment_state_metric
		(@{$Codestriker::comment_state_metrics}) {
                if ( exists($comment_state_metric->{show_on_mainpage}) ) {
                    foreach my $value
			(@{$comment_state_metric->{show_on_mainpage}}) {
                    
			    my $count = $dbh->selectrow_array('
                            SELECT count(commentstatemetric.value) 
                            FROM commentstatemetric, commentstate 
                            WHERE  commentstate.topicid = ? and
                                   commentstate.id = commentstatemetric.id and
                                   commentstatemetric.name = ? and
                                   commentstatemetric.value = ?',
                                   {}, $topicrow->{id},
				   $comment_state_metric->{name}, $value);

                        push @$comment_metric_counts,
			     { name => $comment_state_metric->{name},
			       value => $value,
			       count => $count };
                    }
                }
            }
        }

        $topicrow->{commentmetrics} = $comment_metric_counts;

        # See if the specified user has hit the topic yet.
	# TODO: This should be in the HistoryRecorder module, called
	# From ListTopics.pm, not from here.
        my $visited = $dbh->selectrow_array('
            SELECT count(creation_ts) FROM topicviewhistory 
            WHERE  topicid = ? and
                   email = ?',
                   {}, $topicrow->{id}, $topicrow->{email});

        $topicrow->{visitedtopic} = $visited;
    }


    $database->release_connection();
    die $dbh->errstr unless $success;
}

# Add the condition to the specified query string, returning the new query.
sub _add_condition($$\$) {
    my ($query, $condition, $first_cond_ref) = @_;

    return $query if ($condition eq ""); # Nothing to do.
    if ($$first_cond_ref) {
	$$first_cond_ref = 0;
	$query .= " WHERE (" . $condition . ") ";
    } else {
	$query .= " AND (" . $condition . ") ";
    }
    return $query;
}

# Delete the specified topic.
sub delete($) {
    my ($self) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Create the prepared statements.
    my $delete_topic = $dbh->prepare_cached('DELETE FROM topic WHERE id = ?');
    my $select = $dbh->prepare_cached('SELECT id FROM commentstate ' .
				      'WHERE topicid = ?');
    my $delete_comments =
	$dbh->prepare_cached('DELETE FROM commentdata ' .
			     'WHERE commentstateid = ?');

    my $delete_commentstate_metric =
	$dbh->prepare_cached('DELETE FROM commentstatemetric ' .
			     'WHERE id = ?');

    my $delete_commentstate =
	$dbh->prepare_cached('DELETE FROM commentstate ' .
			     'WHERE topicid = ?');
    my $delete_file =
	$dbh->prepare_cached('DELETE FROM topicfile WHERE topicid = ?');

    my $delete_delta =
	$dbh->prepare_cached('DELETE FROM delta WHERE topicid = ?');

    my $topic_metrics =
	$dbh->prepare_cached('DELETE FROM topicmetric WHERE topicid = ?');

    my $user_metrics =
	$dbh->prepare_cached('DELETE FROM topicusermetric WHERE topicid = ?');

    my $topic_history =
	$dbh->prepare_cached('DELETE FROM topichistory WHERE topicid = ?');

    my $topic_view_history =
	$dbh->prepare_cached('DELETE FROM topicviewhistory WHERE topicid = ?');

    my $commentstate_history =
	$dbh->prepare_cached('DELETE FROM commentstatehistory WHERE id = ?');
    
    my $obsolete_records =
	$dbh->prepare_cached('DELETE FROM topicobsolete WHERE ' .
			     'topicid = ? OR obsoleted_by = ?');

    my $success = defined $delete_topic && defined $delete_comments &&
	defined $delete_commentstate && defined $select &&
	defined $delete_file && defined $delete_delta && 
	defined $topic_metrics && defined $user_metrics &&
	defined $topic_history && defined $topic_view_history &&
	defined $commentstate_history && $delete_commentstate_metric &&
	defined $obsolete_records;

    # Now do the deed.
    $success &&= $select->execute($self->{topicid});
    if ($success) {
	while (my ($commentstateid) = $select->fetchrow_array()) {
	    $success &&= $delete_comments->execute($commentstateid);
	    $success &&= $commentstate_history->execute($commentstateid);
            $success &&= $delete_commentstate_metric->execute($commentstateid);
	}
	$success &&= $select->finish();
    }
    $success &&= $delete_commentstate->execute($self->{topicid});
    $success &&= $delete_topic->execute($self->{topicid});
    $success &&= $delete_comments->execute($self->{topicid});
    $success &&= $delete_file->execute($self->{topicid});
    $success &&= $delete_delta->execute($self->{topicid});
    $success &&= $topic_metrics->execute($self->{topicid});
    $success &&= $user_metrics->execute($self->{topicid});
    $success &&= $self->_delete_bug_ids($dbh);
    $success &&=
	$self->_delete_participants($dbh, $Codestriker::PARTICIPANT_REVIEWER);
    $success &&=
	$self->_delete_participants($dbh, $Codestriker::PARTICIPANT_CC);
    $success &&= $topic_history->execute($self->{topicid});
    $success &&= $topic_view_history->execute($self->{topicid});
    $success &&= $obsolete_records->execute($self->{topicid},
					    $self->{topicid});

    Codestriker::DB::DBI->release_connection($dbh, $success);

    # Indicate the success of the operation.
    return $success ? $Codestriker::OK : $Codestriker::INVALID_TOPIC;
}

1;
