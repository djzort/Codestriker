###############################################################################
# Copyright (c) 2003 Jason Remillard.  All rights reserved.
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling metric data.

package Codestriker::Model::Metrics;

use strict;

use Codestriker::DB::DBI;

sub new {
    my ($class, $topicid) = @_;

    my $self = {};
        
    $self->{topicmetrics} = undef;
    $self->{topicid} = $topicid;
    $self->{usermetrics} = {};
    $self->{topichistoryrows} = undef;

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
	for (my $index = 0; $index < scalar(@stored_metrics); ++$index) {
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

	push @topic_metrics, $self->_get_built_in_topic_metrics();

	$self->{topicmetrics} = \@topic_metrics;
    }

    return @topic_metrics;
}

# Get a list of users that have metric data for this topic. People can 
# look at the topic even if they were not invited, so if somebody touches the 
# topic, they will appear in this list. Using this function rather than the 
# invite list from the topic will insure that people don't get missed from 
# the metric data.
sub get_complete_list_of_topic_participants {

    my ($self) = @_;

    my $dbh = Codestriker::DB::DBI->get_connection();


    my @metric_user_list = @{ $dbh->selectall_arrayref('
	    SELECT distinct email 
	    from participant where topicid = ?',{}, $self->{topicid})};

    push @metric_user_list, @{ $dbh->selectall_arrayref('
	    SELECT author from topic where id = ?',{}, $self->{topicid})};

    push @metric_user_list, @{ $dbh->selectall_arrayref('
	    SELECT distinct email from topicusermetric 
	    where topicid = ?',{}, $self->{topicid})};
    
    push @metric_user_list, @{ $dbh->selectall_arrayref(
	    'SELECT distinct author from commentdata, commentstate ' .
	    'where commentstate.topicid = ? and 
		   commentstate.id = commentdata.commentstateid ',
		   {}, $self->{topicid})};

    push @metric_user_list, @{ $dbh->selectall_arrayref(
	    'SELECT distinct email from topicviewhistory ' .
	    'where topicid = ? and email is not null',{}, $self->{topicid})};

    # remove the duplicates.

    my %metric_user_hash;
    foreach my $user (@metric_user_list) {
	$metric_user_hash{$user->[0]} = 1;
    }

    # Need to sort the empty user name last so that the template parameters 
    # that are done by index don't start at 1, and therefor not allow users
    # to save the metrics.
    @metric_user_list = sort { 
        return 1  if ( $a eq "");
        return -1 if ( $b eq "");
        return $a cmp $b; 
    } keys %metric_user_hash;

    # Close the connection, and check for any database errors.
    Codestriker::DB::DBI->release_connection($dbh, 1);

    return @metric_user_list;
}

# Sets the metrics for a specific user, both authors and reviewers. cc's don't 
# get metrics. The metrics are sent in as an array, that must in the same 
# order as the get_user_metric() call returns them. Metrics that are bad are 
# silently not stored.
sub set_user_metric {
    my ($self, $user, @metric_values) = @_;

    my @metrics = $self->get_user_metrics($user);

    for (my $index = 0; $index < scalar(@metrics); ++$index) {
	next if ($metrics[$index]->{enabled} == 0);
	die "error: not enough metrics" if (scalar(@metric_values) == 0);

	# Disabled values may be in the database (somebody turned off
	# the metrics).  However, they are not paramters so the index
	# between the paramters and the metrics objects will not
	# match.
	my $value = shift @metric_values;

	if ($self->_verify_metric($metrics[$index], $value) eq '') {
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

		    if ($stored_metric->[0] eq $metric_schema->{name}) {
			$metric->{value} = $stored_metric->[1];
			$metric->{in_database} = 1;
			splice @stored_metrics, $index,1;
			last;
		    }
		}

		if ($metric_schema->{enabled} || $metric->{in_database}) {
                    
                    if ($username eq "") {
                        # don't let any metrics be set into the db for unknown users.
                        $metric->{enabled} = 0;
                    }

		    push @user_metrics, $metric;
		}
	    }
	}

	# Clean up any metrics that are in the database but not in the
	# schema, we will not let them change them, and we don't have
	# the description anymore.
	for (my $index = 0; $index < scalar(@stored_metrics); ++$index) {
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

    push @user_metrics, $self->_get_built_in_user_metrics($username);

    return @user_metrics;
}


# Returns the user metrics as a collection of references to hashs. 
sub get_user_metrics_totals {
    my ($self,@users) = @_;

    my @user_metrics;

    if (exists($self->{usermetrics_totals})) {
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

# Returns a list of hashes. Each hash is an event. In the hash is stored who 
# caused the event, when it happened, and what happened. The hashes are defined
# as: 
#   email -> the email address of the user who caused the event.
#   date  -> when the event happened.
#   description -> the event description.
#
# The topic must be loaded from the db before this function can be called.
sub get_topic_history {
    my ($self) = @_;

    my @topic_history = $self->_get_topic_history_rows();

    my @event_list;

    my $last_history_row;

    foreach my $current_history_row ( @topic_history) {
	if ( !defined($last_history_row) ) {
	    # The first event is always the topic creation, so lets make 
	    # that now.
	    
	    my $filteredemail = 
		Codestriker->filter_email($current_history_row->{author});

	    my $formatted_time = 
	        Codestriker->format_short_timestamp($current_history_row->{modified_ts});
    
	    push @event_list, 
	    { 
		email=>$filteredemail,
		date =>$formatted_time,
		description=>'The topic is created.' 
	    };
	}
	else {
	    my %event = 
	    ( 
		email=> Codestriker->filter_email(
			$current_history_row->{modified_by}),
		date => Codestriker->format_short_timestamp(
			$current_history_row->{modified_ts}),
		description=>'' 
	    );

	    # Look for changes in all of the fields. Several fields could have 
	    # changed at once.

	    if ($current_history_row->{author} ne $last_history_row->{author}) {
		my %new_event = %event;
		$new_event{description} = 
		    "Author changed: $last_history_row->{author} to " . 
		    "$current_history_row->{author}.";
		push @event_list, \%new_event;
	    }

	    if ($current_history_row->{title} ne $last_history_row->{title}) {
		my %new_event = %event;
		$new_event{description} = 
		    "Title changed to: \"$current_history_row->{title}\".";
		push @event_list, \%new_event;
	    }

	    if ($current_history_row->{description} ne $last_history_row->{description}) {
		my %new_event = %event;
		$new_event{description} = "Description changed to: " . 
		    "$current_history_row->{description}.";
		push @event_list, \%new_event;

	    }

	    if ($current_history_row->{state} ne $last_history_row->{state}) {
		my %new_event = %event;
		$new_event{description} = 
		    "Topic state changed to: " . 
		    $Codestriker::topic_states[$current_history_row->{state}];
		push @event_list, \%new_event;

	    }

	    if ($current_history_row->{repository} ne $last_history_row->{repository}) {
		my %new_event = %event;
		$new_event{description} = 
		    "Repository changed to: $current_history_row->{repository}.";
		push @event_list, \%new_event;

	    }

	    if ($current_history_row->{project} ne $last_history_row->{project}) {
		my %new_event = %event;
		$new_event{description} = 
		    "Project changed to: $current_history_row->{project}.";
		push @event_list, \%new_event;
	    }

	    if ($current_history_row->{reviewers} ne $last_history_row->{reviewers}) {
		my %new_event = %event;

		# Figure out who was removed, and who was added to the list.
		my @reviewers = split /,/,$current_history_row->{reviewers};
		my @l_reviewers = split /,/,$last_history_row->{reviewers};
		my @new;
		my @removed;

                Codestriker::set_differences(\@reviewers, \@l_reviewers, \@new, \@removed);

		if (@new == 0) {
    		    $new_event{description} = 
			"Reviewers removed: " . join(',',@removed);;
		}
		elsif (@removed == 0) {
    		    $new_event{description} = 
			"Reviewers added: " . join(',',@new);
		}
		else {
    		    $new_event{description} = 
			"Reviewers added: " . join(',',@new) . 
			" and reviewers removed: " . join(',',@removed);
		}

		push @event_list, \%new_event;
	    }

	    if ($current_history_row->{cc} ne $last_history_row->{cc}) {
		my %new_event = %event;
		$new_event{description} = 
		    "CC changed to $current_history_row->{cc}.";
		push @event_list, \%new_event;
	    }
	}

	$last_history_row = $current_history_row
    }
    
    return @event_list;
}

# Returns the topic metrics as a collection of references to
# hashes. The hash that is returned has the same keys as the
# metrics_schema hash, plus a value key. This private function
# returns "built in" metrics derived from the topic history
# table.
sub _get_built_in_topic_metrics {
    my $self = shift;

    my @topic_metrics;

    my @topic_history = $self->_get_topic_history_rows();

    my %state_times;

    my $last_history_row;

    # Figure out how long the topic has spent in each state.

    for ( my $topic_history_index = 0; 
	  $topic_history_index <= scalar(@topic_history);
	  ++$topic_history_index) {
	
	my $current_history_row;
	
	if ($topic_history_index < scalar(@topic_history)) {
	    $current_history_row = $topic_history[$topic_history_index];
	}

	if (defined($last_history_row)) {
	    my $start = 
		Codestriker->convert_date_timestamp_time( 
		    $last_history_row->{modified_ts});
	    my $end   = 0;
	    
	    if (defined($current_history_row)) {
		$end = Codestriker->convert_date_timestamp_time( 
		    $current_history_row->{modified_ts});
	    }
	    else {
		$end = time();
	    }

	    if (exists($state_times{$last_history_row->{state}})) {
		$state_times{$last_history_row->{state}} += $end - $start;
	    }
	    else {
		$state_times{$last_history_row->{state}} = $end - $start;
	    }
	}

	$last_history_row = $current_history_row
    }

    foreach my $state ( sort keys %state_times) {
	my $statename = $Codestriker::topic_states[$state];
	my $time_days = sprintf("%1.1f",$state_times{$state} / (60*60*24));

	# This is the topic metric.
	my $metric =
	    {
	    name         => 'Time In ' . $statename,
	    description  => 
		'Time in days the topic spent in the ' . $statename . ' state.',
	    value        => $time_days,

	    # User can not change the metric, not configured.
	    enabled      => 0,
	    in_database  => 0,
	    filter       =>"count",
	    builtin      => 1,
	    };	

	push @topic_metrics, $metric;
    }

    return @topic_metrics;
}


# Returns the user topic metrics as a collection of references to
# hashs. The hash that is returned has the same keys as the
# metrics_schema hash, plus a value key. This private function
# returns "built in" metrics derived from the topic history
# table and the topic view history table.
sub _get_built_in_user_metrics {

    my ($self,$username) = @_;

    my @user_metrics;

    my $dbh = Codestriker::DB::DBI->get_connection();

    # Setup the prepared statements.
    my $select_topic = $dbh->prepare_cached('SELECT creation_ts ' .
					    'FROM topicviewhistory ' .
					    'WHERE topicid = ? AND ' .
					    'email = ? ' .
					    'ORDER BY creation_ts');

    $select_topic->execute($self->{topicid}, $username);

    my $total_time = $self->calculate_topic_view_time( $select_topic);

    Codestriker::DB::DBI->release_connection($dbh);

    if ($total_time == 0) {
	$total_time = "";
    }
    else {
	$total_time = sprintf("%1.0f",$total_time / (60));
    }

    # This is the topic metric.
    my $metric =
	{
	name         => 'Codestriker Time',
	description  => 
	    'Time in minutes spent in Codestriker looking at this topic.',
	value        => $total_time,
	enabled      => 0,
	in_database  => 0,
	filter       =>"minutes",
	builtin      => 1,
	scope        =>'participant',
	};	

    push @user_metrics, $metric;

    return @user_metrics;
}

# Given a DBI statement that returns a sorted collection of timestamps from 
# the topicviewhistory table, return the total time.
sub calculate_topic_view_time {

    my ($self,$select_topic) = @_;

    # The amount of time you give to people after a click assuming no other
    # clicks are after it.
    my $time_increment = 4*60;

    my $total_time = 0;
    my $last_time = 0;    

    while ( my @row_array = $select_topic->fetchrow_array) {
	my ($creation_ts) = @row_array;

	my $time = Codestriker->convert_date_timestamp_time($creation_ts);

	if ($last_time) {

	    if ($time - $last_time > $time_increment) {
		$total_time += $time_increment
	    }
	    else {
		$total_time += $time - $last_time;
	    }
	}

	$last_time = $time;
    }

    if ($last_time) {
	$total_time += $time_increment;
    }

    return $total_time;

}

# Returns the topichistory rows as an array of hashes. Each element in the 
# array is a row, each field in the table is a key. It will only fetch if 
# from the db once.
sub _get_topic_history_rows {
    
    my ($self) = @_;

    if (defined( $self->{topichistoryrows}))  {
	return @{$self->{topichistoryrows}};
    }
    else {
	my $dbh = Codestriker::DB::DBI->get_connection();

	my @history_list;

	# Setup the prepared statements.
	my $select_topic = $dbh->prepare_cached('SELECT topichistory.author, ' .
						'topichistory.title, ' .
						'topichistory.description, ' .
						'topichistory.state, ' .
						'topichistory.modified_ts, ' .
						'topichistory.version, ' .
						'topichistory.repository, ' .
						'project.name, ' .
						'topichistory.reviewers, ' .
						'topichistory.cc, ' .
						'topichistory.modified_by_user ' .
						'FROM topichistory, project ' .
						'WHERE topichistory.topicid = ? AND ' .
						'topichistory.projectid = project.id ' .
						'ORDER BY topichistory.version');

	$select_topic->execute($self->{topicid});

	while ( my @row_array = $select_topic->fetchrow_array) {
	    my ($author,$title,$description,$state,$modified_ts, $version,
		$repository,$project,$reviewers,$cc, $modified_by) = @row_array;

	    my %entry = ( 
	      author=>$author,
	      title=>$title,
	      description=>$description,
	      state=>$state,
	      modified_ts=>$modified_ts,
	      version=>$version,
	      repository=>$repository,
	      project=>$project,
	      reviewers=>$reviewers,
	      cc=>$cc, 
	      modified_by=>$modified_by
	      );

	    push @history_list, \%entry;
	}

	Codestriker::DB::DBI->release_connection($dbh);

	$self->{topichistoryrows} = \@history_list;

	return @history_list;
    }
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
		   " must be a valid time in hours. " . HTML::Entities::encode($value) . " was " . 
	           "not saved.<BR>" unless $input_ok;
	}
	elsif ($metric->{filter} eq "minutes") {
	    $input_ok = ($value =~ /(^[\d]+)|(^$)/);
	    $msg = $metric->{name} .
		   " must be a valid time in minutes. " . HTML::Entities::encode($value) . " was " . 
	           "not saved.<BR>" unless $input_ok;
	}
	elsif ($metric->{filter} eq "count") {
	    $input_ok = ($value =~ /(^[\d]+$)|(^$)/);
	    $msg = $metric->{name} . 
		   " must be a valid count. " . HTML::Entities::encode($value) . " was not " . 
	           "saved.<BR>" unless $input_ok;
	}
	elsif ($metric->{filter} eq "percent") {
	    $input_ok = ($value =~ /(^[\d]+(\.[\d]*)?$)|(^$)/);

	    if ($input_ok && $value ne '') {
		$input_ok = 0 unless ($value >= 0.0 && $value <= 100.0);
	    }
	    $msg = $metric->{name} . 
		   " must be a valid percent, between 0 and 100. " . 
	           HTML::Entities::encode($value) . " was not saved.<BR>" unless $input_ok;
	}
	else {
	    # invalid config.
	    $input_ok = 0;
	    $msg = HTML::Entities::encode($metric->{name}) . 
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

	    next if ($metric->{builtin});

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
	# don't save built in metrics

	next if ($metric->{builtin});

	if ($metric->{in_database}) {

	    if ($metric->{value} ne '') {
		$update_topic_metric->execute($metric->{value}, 
					      $self->{topicid}, 
					      $metric->{name});
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

