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
    my $create = $dbh->prepare_cached('INSERT INTO PROJECT ' .
				      '(name, description, creation_ts, ' .
				      'modified_ts, version ) ' .
				      'VALUES (?, ?, ?, ?, ?) ');
    $success &&=
	$create->execute($name, $description, $timestamp, $timestamp, 0);
    $success &&= $create->finish();

    Codestriker::DB::DBI->release_connection($dbh, $success);
    return $rc;
}

# Return all projects in the system.
sub list($) {
    my ($type) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Store the results into an array of objects.
    my @results = ();

    # Retrieve all of the comment information for the specified topicid.
    my $select =
	$dbh->prepare_cached('SELECT id, name, description, version ' .
			     'FROM project ORDER BY creation_ts');
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
	    push @results, $project;
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

    my $select = $dbh->prepare_cached('SELECT name, description, version ' .
				      'FROM project WHERE id = ?');
    my $success = defined $select;
    $success &&= $select->execute($id);
    my ($name, $description, $version);
    if ($success &&
	! (($name, $description, $version) = $select->fetchrow_array())) {
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
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);

    return $project;
}

# Update the project details.
sub update($$$$$) {
    my ($type, $id, $name, $description, $version) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Check that the version reflects the current version in the DB.
    my $select =
	$dbh->prepare_cached('SELECT version FROM project ' .
			     'WHERE id = ?');
    my $update =
	$dbh->prepare_cached('UPDATE project SET version = ?, ' .
			     'name = ?, description = ?, modified_ts = ? ' .
			     'WHERE id = ?');

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
				  $timestamp, $id);
    Codestriker::DB::DBI->release_connection($dbh, $success);
    return $rc;
}

1;
