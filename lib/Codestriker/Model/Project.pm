###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling project data.

package Codestriker::Model::Project;

use strict;
use Carp;
use Encode qw(decode_utf8);

use Codestriker::DB::DBI;

# Simple private method which returns the mapping of project state id to
# its textual representation.
sub _state_id_to_string {
    my ($id) = @_;
    return 'Open' if $id == 0;
    return 'Closed' if $id == 1;
    return 'Deleted' if $id == 2;
    return "State $id";
}

# Simple private method which returns the mapping of project state to
# its id.
sub _state_string_to_id {
    my ($state) = @_;
    return 0 if $state eq 'Open';
    return 1 if $state eq 'Closed';
    return 2 if $state eq 'Deleted';
    return 3;
}

# Create a new project with all of the specified properties.
sub create($$$$) {
    my ($type, $name, $description) = @_;

    my $rc = $Codestriker::OK;
    
    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Check that a project with this name doesn't already exist.
    my $select = $dbh->prepare_cached('SELECT COUNT(*) FROM project ' .
				      'WHERE name = ?');
    my $success = defined $select;
    $success &&= $select->execute($name);
    if ($success) {
	my ($count) = $select->fetchrow_array();
	$select->finish();
	if ($count != 0) {
	    $success = 0;
	    $rc = $Codestriker::DUPLICATE_PROJECT_NAME;
	}
    }

    # Create the project entry.
    my $timestamp = Codestriker->get_timestamp(time);
    my $create = $dbh->prepare_cached('INSERT INTO project ' .
				      '(name, description, creation_ts, ' .
				      'modified_ts, version, state ) ' .
				      'VALUES (?, ?, ?, ?, ?, ?) ');
    $success &&=
	$create->execute($name, $description, $timestamp, $timestamp, 0, 0);
    $success &&= $create->finish();

    Codestriker::DB::DBI->release_connection($dbh, $success);
    return $rc;
}

# Return all projects in the system.
sub list($$) {
    my ($type, $state) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Store the results into an array of objects.
    my @results = ();

    # Retrieve all of the comment information for the specified topicid.
    my $select =
	$dbh->prepare_cached('SELECT id, name, description, version, state ' .
			     'FROM project ORDER BY state, name, creation_ts');
    my $success = defined $select;
    $success &&= $select->execute();

    # Store the results in the array.
    if ($success) {
	my @data;
	while (@data = $select->fetchrow_array()) {
	    my $project = {};
	    $project->{id} = $data[0];
	    $project->{name} = decode_utf8($data[1]);
	    $project->{description} = decode_utf8($data[2]);
	    $project->{version} = $data[3];
	    $project->{state} = _state_id_to_string($data[4]);
	    if (!defined $state || $project->{state} eq $state)
	    {
		push @results, $project;
	    }
	}
	$select->finish();
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;

    return @results;
}

# Read the details of a specific project from the database.
sub read($$) {
    my ($type, $id) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    my $select =
	$dbh->prepare_cached('SELECT name, description, version, state ' .
			     'FROM project WHERE id = ?');
    my $success = defined $select;
    $success &&= $select->execute($id);
    my ($name, $description, $version, $state);
    if ($success &&
	! (($name, $description, $version, $state) =
	   $select->fetchrow_array())) {
	$success = 0;
    }
    $success &&= $select->finish();

    my $project = {};
    if ($success) {
	# Populate return object.
	$project->{id} = $id;
	$project->{name} = decode_utf8($name);
	$project->{description} = decode_utf8($description);
	$project->{version} = $version;
	$project->{state} = _state_id_to_string($state);
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);

    return $project;
}

# Update the project details.
sub update($$$$$$) {
    my ($type, $id, $name, $description, $version, $project_state) = @_;

    # Map the new state to its number.
    my $new_stateid = _state_string_to_id($project_state);

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Check that the version reflects the current version in the DB.
    my $select =
	$dbh->prepare_cached('SELECT version FROM project ' .
			     'WHERE id = ?');
    my $update =
	$dbh->prepare_cached('UPDATE project SET version = ?, ' .
			     'name = ?, description = ?, modified_ts = ?, ' .
			     'state = ? WHERE id = ?');

    my $success = defined $select && defined $update;
    my $rc = $Codestriker::OK;

    # Retrieve the current comment data.
    $success &&= $select->execute($id);

    # Make sure that the project still exists, and is therefore valid.
    my $current_version;
    if ($success && ! (($current_version) = $select->fetchrow_array())) {
	# Invalid project id.
	$success = 0;
	$rc = $Codestriker::INVALID_PROJECT;
    }
    $success &&= $select->finish();

    # Check the version number.
    if ($success && $version != $current_version) {
	$success = 0;
	$rc = $Codestriker::STALE_VERSION;
    }

    # Update the project details.
    my $timestamp = Codestriker->get_timestamp(time);
    $success &&= $update->execute($version+1, $name, $description,
				  $timestamp, $new_stateid, $id);
    Codestriker::DB::DBI->release_connection($dbh, $success);
    return $rc;
}

# Update the project details.
sub delete($$) {
    my ($type, $id, $version) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Check that the version reflects the current version in the DB.
    my $select =
	$dbh->prepare_cached('SELECT version FROM project ' .
			     'WHERE id = ?');

    # Create the prepared statements.
    my $delete = $dbh->prepare_cached('DELETE FROM project WHERE id = ?');

    my $success = defined $select && defined $delete;
    my $rc = $Codestriker::OK;

    # Retrieve the current comment data.
    $success &&= $select->execute($id);

    # Make sure that the project still exists, and is therefore valid.
    my $current_version;
    if ($success && ! (($current_version) = $select->fetchrow_array())) {
	# Invalid project id.
	$success = 0;
	$rc = $Codestriker::INVALID_PROJECT;
    }
    $success &&= $select->finish();

    # Check the version number.
    if ($success && $version != $current_version) {
	$success = 0;
	$rc = $Codestriker::STALE_VERSION;
    }

    if ($success == 0) {
	Codestriker::DB::DBI->release_connection($dbh, $success);
	return $rc;
    } else {
	# Delete the topics in this project.
	my @sort_order;
	my @topics = Codestriker::Model::Topic->query("", "", "", "",
						      "", $id, "",
						      "", "", "", "", "",
						      \@sort_order );
	
	# Delete each of the topics for this project
	foreach my $topic ( @topics ) {
	    $topic->delete();
	}

	# Now delete the project.
	$delete->execute($id);
	Codestriker::DB::DBI->release_connection($dbh, $success);

	return $rc;
    }
}

# Determine the number of open topics in the specified project.
sub num_open_topics {
    my ($type, $id) = @_;

    my $dbh = Codestriker::DB::DBI->get_connection();
    my $count;
    eval {
	$count = $dbh->selectrow_array('SELECT COUNT(topic.id) ' .
				       'FROM topic ' .
				       'WHERE topic.projectid = ? ' .
				       'AND topic.state = 0', {}, $id);
    };
    Codestriker::DB::DBI->release_connection($dbh, 1);
    if ($@) {
	carp "Problem retrieving count of open topics in project: $@";
    }

    return $count;
}

# Determine the number of topics in the specified project.
sub num_topics {
    my ($type, $id) = @_;

    my $dbh = Codestriker::DB::DBI->get_connection();
    my $count;
    eval {
	$count = $dbh->selectrow_array('SELECT COUNT(topic.id) ' .
				       'FROM topic ' .
				       'WHERE topic.projectid = ? ', {}, $id);
    };
    Codestriker::DB::DBI->release_connection($dbh, 1);

    if ($@) {
	carp "Problem retrieving count of topics in project: $@";
    }

    return $count;
}


1;
