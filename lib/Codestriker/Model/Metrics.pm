###############################################################################
# Copyright (c) 2003 Jason Remillard.  All rights reserved.
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling metric data.

package Codestriker::Model::Metrics;

use strict;
use warnings;

use Codestriker::DB::DBI;

sub new {
    my ($class, $topicid) = @_;

    my $self = {};
        
    $self->{topicmetrics} = undef;
    $self->{topicid} = $topicid;
    $self->{usermetrics} = {};

    bless $self, $class;
   
    return $self;
}

# Sets the topic metrics values. The values are passed in as an
# array. The array must be in the same order returned by
# get_topic_metric(). Metrics that are bad are silently not stored.
sub set_topic_metrics {
    my ($self,@metric_values) = @_;

    my @metrics = $self->get_topic_metrics();

    for (my $index = 0; $index < scalar(@metrics); ++$index) {
	next if ($metrics[$index]->{enabled} == 0);
	die "error: not enough metrics" if (scalar(@metric_values) == 0);

	my $value = shift @metric_values;

	if ($self->_verify_metric($metrics[$index], $value) eq '') {
	    $metrics[$index]->{value} = $value;
	}
    }
}

# Verifies that all of the topic metrics are well formed and valid. It will
# return a non-empty string if a problem is found.
sub verify_topic_metrics {
    my ($self,@metric_values) = @_;

    my $msg = '';

    my @metrics = $self->get_topic_metrics();

    for (my $index = 0; $index < scalar(@metrics); ++$index) {
	next if ($metrics[$index]->{enabled} == 0);

	# Disabled values may be in the database (somebody turned off
	# the metrics).  However, they are not paramters so the index
	# between the paramters and the metrics objects will not
	# match.
	my $value = shift @metric_values;

	$msg .= $self->_verify_metric($metrics[$index], $value);
    }

    return $msg;
}


# Returns the topic metrics as a collection of references to
# hashs. The hash that is returned has the same keys as the
# metrics_schema hash, plus a value key. If the user has not entered a
# value, it will be set to an empty string.
sub get_topic_metrics {
    my $self = shift;

    my @topic_metrics;

    if (defined($self->{topicmetrics})) {
	# The topic metrics have already been loaded from the
	# database, just return the cached data.
	@topic_metrics = @{$self->{topicmetrics}};
    }
    else {
	my @stored_metrics = ();

	if (defined($self->{topicid})) {
	    # Obtain a database connection.
	    my $dbh = Codestriker::DB::DBI->get_connection();

	    my $select_topic_metrics = 
		$dbh->prepare_cached('SELECT topicmetric.metric_name, 
					     topicmetric.value ' .
				     'FROM topicmetric ' .
		                     'WHERE topicmetric.topicid = ?');
						    
	    $select_topic_metrics->execute($self->{topicid}); 

	    @stored_metrics = @{$select_topic_metrics->fetchall_arrayref()};

	    # Close the connection, and check for any database errors.
	    Codestriker::DB::DBI->release_connection($dbh, 1);
	}

	# Match the configured metrics to the metrics in the database. If 
	# the configured metric is found in the database, it is removed 
	# from the stored_metric list to find any data that is in the 
	# database, but is not configured.
	foreach my $metric_schema (Codestriker::get_metric_schema()) {
	    if ($metric_schema->{scope} eq 'topic') {
		my $metric =
		    { # This is the topic metric.
		    name        => $metric_schema->{name},
		    description => $metric_schema->{description},
		    value       => '',
		    filter      => $metric_schema->{filter},
		    enabled     => $metric_schema->{enabled},
		    in_database => 0
		    };

		for (my $index = 0; $index < scalar(@stored_metrics); ++$index) {
		    my $stored_metric = $stored_metrics[$index];

		    if ($stored_metric->[0] eq $metric_schema->{name}) {
			$metric->{value} = $stored_metric->[1];
			$metric->{in_database} = 1;
			splice @stored_metrics, $index, 1;
			last;
		    }
		}

		if ($metric_schema->{enabled} || $metric->{in_database}) {
		    push @topic_metrics, $metric;
		}
	    }
	}

	# Add in any metrics that are in the database but not
	# currently configured.  The system should display the
	# metrics, but not let the user modify them.
	for(my $index = 0; $index < scalar(@stored_metrics); ++$index) {
	    my $stored_metric = $stored_metrics[$index];

	    # This is the topic metric.
	    my $metric =
		{
		name         => $stored_metric->[0],
		description  => '',
		value        => $stored_metric->[1],

		# User can not change the metric, not configured.
		enabled      => 0,
		in_database  => 1
		};

	    push @topic_metrics, $metric;
	}

	$self->{topicmetrics} = \@topic_metrics;
    }

    return @topic_metrics;
}

# Sets the metrics for a specific user, both authors and reviewers. cc's don't 
# get metrics. The metrics are sent in as an array, that must in the same 
# order as the get_user_metric() call returns them. Metrics that are bad are 
# silently not stored.
sub set_user_metric {
    my ($self, $user, @metric_values) = @_;

    my @metrics = $self->get_user_metrics($user);

    for (my $index = 0; $index < scalar(@metrics); ++$index) {
	next if ( $metrics[$index]->{enabled} == 0);
	die "error: not enough metrics" if (scalar(@metric_values) == 0);

	# Disabled values may be in the database (somebody turned off
	# the metrics).  However, they are not paramters so the index
	# between the paramters and the metrics objects will not
	# match.
	my $value = shift @metric_values;

	if ( $self->_verify_metric($metrics[$index], $value) eq '') {
	    $metrics[$index]->{value} = $value
	}
    }
}

# Verifies that all of the user metrics are well formed and valid inputs. If a 
# problem is found the function will return a non-empty string.
sub verify_user_metrics {
    my ($self, $user, @metric_values) = @_;

    my $msg = '';

    my @metrics = $self->get_user_metrics($user);

    for (my $index = 0; $index < scalar(@metrics); ++$index) {
	next if ( $metrics[$index]->{enabled} == 0);

	# Disabled values may be in the database (somebody turned off
	# the metrics).  However, they are not paramters so the index
	# between the paramters and the metrics objects will not
	# match.
	my $value = shift @metric_values;

	$msg .= $self->_verify_metric($metrics[$index], $value);
    }

    return $msg;
}


# Returns the user metrics as a collection of references to hashs. The
# hash that is returned has the same keys as the metrics_schema hash,
# plus a value key. If the user has not entered a value, it will be
# set to an empty string.
sub get_user_metrics {
    my ($self, $username) = @_;

    my @user_metrics;

    if (exists($self->{usermetrics}->{$username})) {
	# If the metrics for this user has already been loaded from
	# the database, return the cached result of that load.
	@user_metrics = @{$self->{usermetrics}->{$username}};
    }
    else {    
	my @stored_metrics = ();

	if (defined($self->{topicid})) {
	    # Obtain a database connection.
	    my $dbh = Codestriker::DB::DBI->get_connection();


	    # Get all of the user outputs for this topic regardless of
	    # the user.
	    my $selected_all_user_metrics = 
		$dbh->prepare_cached('SELECT DISTINCT metric_name ' .
				     'FROM topicusermetric ' .
				     'WHERE topicid = ? ' .
				     'ORDER BY metric_name');
	    $selected_all_user_metrics->execute($self->{topicid}); 
	    @stored_metrics =
		@{$selected_all_user_metrics->fetchall_arrayref()};

	    # Get the outputs for this user.
	    my $select_user_metrics = 
		$dbh->prepare_cached('SELECT metric_name, value ' .
				     'FROM topicusermetric ' .
				     'WHERE topicid = ? and email = ? ' .
				     'ORDER BY metric_name');

	    $select_user_metrics->execute($self->{topicid}, $username);

	    my @user_stored_metrics =
		@{$select_user_metrics->fetchall_arrayref()};

	    # Stuff the complete list with the values from the current
	    # user list.  Handle displaying metrics that are in the
	    # db, but not enabled for new topics.
	    foreach my $metric (@stored_metrics) {
		my $foundit = 0;
		foreach my $user_metric (@user_stored_metrics) {
		    if ($user_metric->[0] eq $metric->[0]) {
			$foundit = 1;
			push @$metric, $user_metric->[1];
			last;
		    }
		}

		if ($foundit == 0) {
		    push @$metric,'';
		}
	    }

	    # Close the connection, and check for any database errors.
	    Codestriker::DB::DBI->release_connection($dbh, 1);
	}

	foreach my $metric_schema (Codestriker::get_metric_schema()) {
	    if ($metric_schema->{scope} ne 'topic') {
		my $metric = 
		{ 
		    name        => $metric_schema->{name},
		    description => $metric_schema->{description},
		    value       => '',
		    enabled     => $metric_schema->{enabled},
		    scope       => $metric_schema->{scope},
		    filter      => $metric_schema->{filter},
		};


		for (my $index = 0; $index < scalar(@stored_metrics);
		     ++$index) {
		    my $stored_metric = $stored_metrics[$index];

		    if ( $stored_metric->[0] eq $metric_schema->{name}) {
			$metric->{value} = $stored_metric->[1];
			$metric->{in_database} = 1;
			splice @stored_metrics, $index,1;
			last;
		    }
		}

		if ($metric_schema->{enabled} || $metric->{in_database}) {
		    push @user_metrics, $metric;
		}
	    }
	}

	# Clean up any metrics that are in the database but not in the
	# schema, we will not let them change them, and we don't have
	# the description anymore.
	for (my $index = 0; $index < scalar( @stored_metrics); ++$index) {
	    my $stored_metric = $stored_metrics[$index];

	    my $metric =
		{ # this is the topic metric  
		name=>$stored_metric->[0],
		description=>'',
		value=>$stored_metric->[1],
		scope=>'participant',
		enabled=>0, # user can not change the metric, no schema.
		in_database=>1
		};

	    push @user_metrics, $metric;
	}

	$self->{usermetrics}->{$username} = \@user_metrics;
    }

    return @user_metrics;
}


# Returns the user metrics as a collection of references to hashs. 
sub get_user_metrics_totals {
    my ($self,@users) = @_;

    my @user_metrics;

    if (exists($self->{usermetrics_totals}) ) {
	@user_metrics = @$self->{usermetrics_totals};
    }

    my @total_metrics;

    foreach my $user (@users) {
	my @metrics = $self->get_user_metrics($user);

	if (scalar(@total_metrics) == 0) {
	    # Copy the metrics in.

	    foreach my $metric (@metrics) {
		my %temp = %$metric;
		push @total_metrics, \%temp;
	    }
	    
	}
	else {
	    # Add them up!
	    for (my $index = 0; $index < scalar( @total_metrics) ; ++$index) {
		if ($metrics[$index]->{value} ne '') {
		    if ($total_metrics[$index]->{value} eq '') {
			$total_metrics[$index]->{value} = 0;
		    }

		    $total_metrics[$index]->{value} +=
			$metrics[$index]->{value};		
		}
	    }
	}

    }

    $self->{usermetrics_totals}= \@total_metrics;

    return @total_metrics;
}

# Returns an error message if a number is not a valid value for a given metric.
sub _verify_metric {
    my ($self, $metric, $value) = @_;

    my $msg = '';
    if ($metric->{enabled}) {
	my $input_ok = 0;

	if ($metric->{filter} eq "hours") {
	    $input_ok = ($value =~ /(^[\d]+([\.:][\d]*)?$)|(^$)/);
	    $msg = $metric->{name} .
		   " must be a valid time in hours. $value was " . 
	           "not saved.<BR>" unless $input_ok;
	}
	elsif ($metric->{filter} eq "count") {
	    $input_ok = ($value =~ /(^[\d]+$)|(^$)/);
	    $msg = $metric->{name} . 
		   " must be a valid count. $value was not " . 
	           "saved.<BR>" unless $input_ok;
	}
	elsif ($metric->{filter} eq "percent") {
	    $input_ok = ($value =~ /(^[\d]+(\.[\d]*)?$)|(^$)/);

	    if ($input_ok && $value ne '') {
		$input_ok = 0 unless ($value >= 0.0 && $value <= 100.0);
	    }
	    $msg = $metric->{name} . 
		   " must be a valid percent, between 0 and 100. " . 
	           "$value was not saved.<BR>" unless $input_ok;
	}
	else {
	    # invalid config.
	    $input_ok = 0;
	    $msg = $metric->{name} . 
		   " invalid filter type in configuration. Must " . 
	           "be hours, count, or percent.<BR>";
	}
    }

    return $msg;
}

# Stores all of the metrics to the database.
sub store {
    my ($self) = @_;

    $self->_store_topic_metrics();
    $self->_store_user_metrics();
}

# Stores the topic metrics to the database.
sub _store_user_metrics {
    my ($self) = @_;

    foreach my $user (keys %{$self->{usermetrics}}) {
	$self->get_user_metrics($user);
    }

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # flush out the user metrics from the topic,
    my $delete_alluser_metric =
	$dbh->prepare_cached('DELETE FROM topicusermetric ' .
			     'WHERE topicid = ?');

    $delete_alluser_metric->execute($self->{topicid});

    my $insert_user_metric =
	$dbh->prepare_cached('INSERT INTO topicusermetric (topicid, 
						    email, 
						    metric_name, 
						    value) ' .
			     'VALUES (?, ?, ?, ? )');

    foreach my $user (keys %{$self->{usermetrics}}) {
	my @metrics = $self->get_user_metrics($user);

	foreach my $metric (@metrics) {
	    if ($metric->{value} ne '') {
		$insert_user_metric->execute($self->{topicid}, 
					     $user, 
					     $metric->{name}, 
					     $metric->{value});	    
	    }
	}
    }

    # Close the connection, and check for any database errors.
    Codestriker::DB::DBI->release_connection($dbh, 1);
}

# Stores the topic metrics to the database.
sub _store_topic_metrics {
    my ($self) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Store the topic metrics first.
    my @topic_metrics = $self->get_topic_metrics();

    my $insert_topic_metric =
	$dbh->prepare_cached('INSERT INTO topicmetric (topicid, 
						       metric_name, 
						       value) ' .
			     'VALUES (?, ?, ? )');
    my $update_topic_metric =
	$dbh->prepare_cached('UPDATE topicmetric SET value = ? ' .
			     'WHERE topicid = ? and metric_name = ?');

    my $delete_topic_metric =
	$dbh->prepare_cached('DELETE FROM topicmetric ' .
			     'WHERE topicid = ? and metric_name = ?');

    foreach my $metric (@topic_metrics) {
	if ($metric->{in_database}) {

	    if ($metric->{value} ne '') {
		$update_topic_metric->execute($metric->{value}, 
					      $self->{topicid}, 
					      $metric->{name} );
	    }
	    else {
		# Delete the row.
		$delete_topic_metric->execute($self->{topicid},
					      $metric->{name});
		$metric->{in_database} = 0;
	    }
	}
	else {

	    # New metric that is not in the datbase.
	    if ($metric->{value} ne '') {
		$insert_topic_metric->execute($self->{topicid}, 
					      $metric->{name},
					      $metric->{value});
		$metric->{in_database} = 1;
	    }
	}

	$metric->{in_database} = 1;
    }

    # Close the connection, and check for any database errors.
    Codestriker::DB::DBI->release_connection($dbh, 1);
}

1;

