###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling project data.

package Codestriker::Model::Project;

use strict;

use Codestriker::DB::DBI;

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
	    $project->{name} = $data[1];
	    $project->{description} = $data[2];
	    $project->{version} = $data[3];
	    $project->{state} = $Codestriker::project_states[$data[4]];
	    if (!defined $state ||
		$project->{state} eq $Codestriker::project_states[$state])
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

    my $select = $dbh->prepare_cached('SELECT name, description, version, state ' .
				      'FROM project WHERE id = ?');
    my $success = defined $select;
    $success &&= $select->execute($id);
    my ($name, $description, $version, $state);
    if ($success &&
	! (($name, $description, $version, $state) = $select->fetchrow_array())) {
	$success = 0;
    }
    $success &&= $select->finish();

    my $project = {};
    if ($success) {
	# Populate return object.
	$project->{id} = $id;
	$project->{name} = $name;
	$project->{description} = $description;
	$project->{version} = $version;
	$project->{state} = $Codestriker::project_states[$state];
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);

    return $project;
}

# Update the project details.
sub update($$$$$$) {
    my ($type, $id, $name, $description, $version, $project_state) = @_;

    # Map the new state to its number.
    my $new_stateid;
    for ($new_stateid = 0; $new_stateid <= $#Codestriker::project_states;
	 $new_stateid++) {
	last if ($Codestriker::project_states[$new_stateid] eq $project_state);
    }
    if ($new_stateid > $#Codestriker::project_states) {
	die "Unable to change project to invalid state: \"$project_state\"";
    }

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

    # Delete the project details.
    $success &&= $delete->execute($id);
    Codestriker::DB::DBI->release_connection($dbh, $success);

    # Now delete all of the topics for this Project

    # Retrieve the current state of the topic.
    my $topic = Codestriker::Model::Topic->new();

    # Query the model for the specified data.
    my (@sort_order, @state_group_ref, @text_group_ref);
    my (@topicids, @title, @author, @ts, @state, @bugid, @email, @type, @version);

    Codestriker::Model::Topic->query("", "", "", "",
				     "", $id, "",
				     "", "",
				     "", "", "",
                                     \@sort_order,
				     \@topicids, \@title,
				     \@author, \@ts, \@state, \@bugid,
				     \@email, \@type, \@version);

    # Delete each of the topics for this project
    for (my $index = 0; $index <= $#topicids; $index++) {
	my $accum_id = $topicids[$index];

	my $topic_delete = Codestriker::Model::Topic->new($accum_id);
	$topic_delete->delete();
    }

    return $rc;
}

1;
