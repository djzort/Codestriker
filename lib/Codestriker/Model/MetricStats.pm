###############################################################################
# Copyright (c) 2003 Jason Remillard.  All rights reserved.
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling metrics reports. This object is not an object, it
# is a normal module.

package Codestriker::Model::MetricStats;

use strict;
use Encode qw(decode_utf8);

use Codestriker::DB::DBI;

my $total_participants_header = 'Total Participants';
my $topic_size_lines_header = 'Topic Size In Lines';

# Returns the list of users that have participated in a Codestriker topics.
#
# 
# Returns a collection of the following hash references.
# {
#   name
#   date_last_authored
#   date_last_participated
#   total_topics
# }

sub get_basic_user_metrics {
    # Gather basic user metrics for the past 16 weeks.
    my $last_n_days = 16*7;

    my $date = Codestriker->get_timestamp(time-($last_n_days*24*60*60));

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Get the list of authors.
    my $author_list = $dbh->selectall_arrayref(
	    'SELECT author,MAX(modified_ts),COUNT(id)
	     FROM topic 
	     WHERE modified_ts >= ?
	     GROUP BY author
	     ORDER BY 2 desc', {}, $date);

    my @users_metrics;

    foreach my $row (@$author_list) {
	my ($name, $last_authored_date, $count) = @$row;

	my $metrics = 
	{
	    name=>$name,
	    date_last_authored=>
		int((time() - Codestriker->convert_date_timestamp_time($last_authored_date))/(60*60*24)),
	    date_last_participated=>'',
	    total_codestriker_time => 
		calculate_topic_view_time_for_user($date,$name),
	    total_topics=>$count,
	};

	push(@users_metrics, $metrics);
    }
 
    # Get the list of participants from all these topics. You need to 
    # submit at least one comment to be counted.
    my $participant_list = $dbh->selectall_arrayref(
	    'SELECT commentdata.author, 
		    MAX(topic.modified_ts), 
		    COUNT(DISTINCT topic.id)
	     FROM commentdata, commentstate, topic 
	     WHERE topic.modified_ts >= ? AND 
		   topic.id = commentstate.topicid AND 
		   topic.author <> commentdata.author AND
		   commentdata.commentstateid = commentstate.id
	     GROUP BY commentdata.author
	     ORDER BY 2 desc',{}, $date);
     
    foreach my $row (@$participant_list) {
	my ($name, $last_participated_date, $count) = @$row;

	my $found = 0;
	foreach my $user (@users_metrics) {
	    if ($user->{name} eq $name) {
		$user->{date_last_participated} = 
		    int((time() - 
		    Codestriker->convert_date_timestamp_time($last_participated_date))/(60*60*24));
		$user->{total_topics} += $count;
		$found = 1;
	    }
	}

	if ($found == 0) {
	    my $metrics = 
	    {
		name=>$name,
		date_last_authored=>'',
		date_last_participated=>
		    int((time() - 
		    Codestriker->convert_date_timestamp_time($last_participated_date))/(60*60*24)),
		total_topics=>$count,
		total_codestriker_time => 
		    calculate_topic_view_time_for_user($date,$name),
	    };

	    push(@users_metrics, $metrics);
	}
    }

    # Close the connection, and check for any database errors.
    Codestriker::DB::DBI->release_connection($dbh, 1);

    return @users_metrics;
}

# Given the username, and the oldest date, calculate the total amount of 
# codestriker time that was recorded in hours.
sub calculate_topic_view_time_for_user {
    my ($date,$user) = @_;

    # get the total time for this user.
    my $dbh = Codestriker::DB::DBI->get_connection();

    my $select_topic = $dbh->prepare_cached('SELECT creation_ts ' .
					    'FROM topicviewhistory ' .
					    'WHERE creation_ts > ? AND ' .
					    'email = ? ' .
					    'ORDER BY creation_ts');

    $select_topic->execute($date,$user);

    my $total_time = 
	Codestriker::Model::Metrics->calculate_topic_view_time($select_topic);

    Codestriker::DB::DBI->release_connection($dbh);

    $total_time = sprintf("%1.1f",$total_time / (60*60));

    return $total_time;
}


# Returns a list of all the topic ids in the database.
sub get_topic_ids {
    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Get the list of authors.
    my $topicid_list  = $dbh->selectall_arrayref(
	    'SELECT id FROM topic ORDER BY creation_ts');

    # Close the connection, and check for any database errors.
    Codestriker::DB::DBI->release_connection($dbh, 1);

    return @$topicid_list;

}

# Returns in a hash the column names for the raw metric download feature.
sub get_download_headers {
    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    my @base_headers = qw(
	TopicID
	Author
	Title
	State
	Creation
	Project
	);

    # Comment metric counts.
    my @comment_metric_headers;
    my $comment_metrics = $dbh->selectall_arrayref(
	    'SELECT DISTINCT name
	     FROM commentstatemetric 
	     ORDER BY name
	    ');
    foreach my $metric (@$comment_metrics) {
	push @comment_metric_headers, $metric->[0];
    }

    # Do the built-in comment metrics.
    push @comment_metric_headers, 'Comment Threads';
    push @comment_metric_headers, 'Submitted Comments';

    # Topic metrics counts.
    my @topic_metric_headers;
    my $topic_metrics = $dbh->selectall_arrayref(
	    'SELECT DISTINCT metric_name 
	     FROM topicmetric
	     ORDER by metric_name
	    ');

    foreach my $metric (@$topic_metrics) {
	push @topic_metric_headers, $metric->[0];
    }

    # Do the built in topic metrics.
    for (my $state = 0; $state < scalar(@Codestriker::topic_states);
	 ++$state) {
	push @topic_metric_headers, 
	    'Time In ' . $Codestriker::topic_states[$state];
    }

    push @topic_metric_headers, $topic_size_lines_header;

    my @topic_user_metric_headers;

    # User topic metrics counts.
    my $user_topic_metrics  = $dbh->selectall_arrayref(
	    'SELECT DISTINCT metric_name 
	     FROM topicusermetric
	     ORDER by metric_name
	    ');

    foreach my $metric (@$user_topic_metrics) {
	push @topic_user_metric_headers, $metric->[0];
    }
    
    # Do the built in user metrics.
    push @topic_user_metric_headers, 'Codestriker Time';
    push @topic_user_metric_headers, $total_participants_header;
    
    my $headers = 
    {
	base => \@base_headers,
	comment => \@comment_metric_headers,
	topic => \@topic_metric_headers,
	user => \@topic_user_metric_headers
    };

    # Close the connection, and check for any database errors.
    Codestriker::DB::DBI->release_connection($dbh, 1);

    return $headers;
}

# Given a topic id, and a header hash, return an list with all of the
# topics metric data returned in the order given by the header
# information.
sub get_raw_metric_data {
    my ($topicid, $headers) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    my @basic_topic_info = $dbh->selectrow_array('
	    SELECT topic.id, 
		   topic.author, 
		   topic.title, 
		   topic.state, 
		   topic.creation_ts, 
		   project.name 
	    FROM topic, project
	    WHERE topic.id = ? AND 
		  topic.projectid = project.id',{}, $topicid);

    # Decode topic title and project name.
    $basic_topic_info[2] = decode_utf8($basic_topic_info[2]);
    $basic_topic_info[5] = decode_utf8($basic_topic_info[5]);

    if ($basic_topic_info[3] < @Codestriker::topic_states) {
	$basic_topic_info[3] = 
	    @Codestriker::topic_states[$basic_topic_info[3]];
    }

    $basic_topic_info[4] =
	Codestriker->format_date_timestamp($basic_topic_info[4]);

    $basic_topic_info[1] =
	Codestriker->filter_email($basic_topic_info[1]);

    my @row;

    push @row, @basic_topic_info;

    # Process the comment metric values.
    my $count_query =
	$dbh->prepare_cached('SELECT COUNT(*) ' .
			     'FROM topic, commentstate, commentstatemetric ' .
			     'WHERE topic.id = ? AND ' .
                             'topic.id = commentstate.topicid AND ' .
			     'commentstate.id = commentstatemetric.id AND '.
			     'commentstatemetric.name = ? ');
    foreach my $metric (@{$headers->{comment}}) {
	# Get the count for this metric name.
	$count_query->execute($topicid, $metric);
	my ($count) = $count_query->fetchrow_array();
	$count_query->finish();
	push @row, $count;
    }

    # Now process the 'Comment Threads' metric.
    my $comment_threads = $dbh->selectall_arrayref(
	    'SELECT COUNT(id)
	     FROM commentstate 
	     WHERE topicid = ?
	    ',{}, $topicid);
    push @row, $comment_threads->[0]->[0];

    # Now process the 'Submitted Comments' metric.
    my $submitted_comments = $dbh->selectall_arrayref(
	    'SELECT COUNT(id)
	     FROM commentstate, commentdata
	     WHERE commentstate.topicid = ?
             AND commentstate.id = commentdata.commentstateid
	    ',{}, $topicid);
    push @row, $submitted_comments->[0]->[0];
    
    my $topic = Codestriker::Model::Topic->new($basic_topic_info[0]);     

    my $metrics = $topic->get_metrics();

    my @topic_metrics = $metrics->get_topic_metrics();
    
    for (my $index = 0; $index < scalar(@{$headers->{topic}}); ++$index) {
	my $count = "";

	foreach my $metric ( @topic_metrics ) {
	    $count = $metric->{value} 
		if ($metric->{name} eq $headers->{topic}->[$index]);
	}

	if ($headers->{topic}->[$index] eq $topic_size_lines_header ) {
	    $count = $topic->get_topic_size_in_lines();
	}

	push @row, $count;
    } 

    # Get the list of users for this review.
    my @users = $metrics->get_complete_list_of_topic_participants();
    
    my @user_metrics = $metrics->get_user_metrics_totals(@users);
    
    for (my $index = 0; $index < scalar(@{$headers->{user}}); ++$index) {
	my $count = "";

	foreach my $metric ( @user_metrics ) {
	    $count = $metric->{value} 
		if ($metric->{name} eq $headers->{user}->[$index]);
	}

	if ($headers->{user}->[$index] eq $total_participants_header) {
	    # Add the total number of participants in the topic.
	    $count = scalar(@users);
	}

	push @row, $count;
    } 


    # Close the connection, and check for any database errors.
    Codestriker::DB::DBI->release_connection($dbh, 1);

    return @row;
}

# Returns 12 months of comment metrics data.
#
# returns a collection of the following hash references
# {
#   name  = the comment metric name
#   results = collection ref to 
#             {
#               name = the comment value name. 
#               counts = array ref to metric counts per month
#               monthnames = array ref to month names
#             }
# }
sub get_comment_metrics {
    # Stores the collection results.
    my @results = ();

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Get the comment metric totals.
    foreach my $metric_config (@{ $Codestriker::comment_state_metrics }) {
	my $metric_name = $metric_config->{name};
	my $query =
	    "SELECT commentstatemetric.value, COUNT(commentstate.id) " .
	    "FROM commentstate, commentstatemetric " .
	    "WHERE commentstatemetric.id = commentstate.id AND " .
	    "commentstatemetric.name = " . $dbh->quote($metric_name) . " AND " .
	    "commentstate.creation_ts > ? AND " .
	    "commentstate.creation_ts <= ? " .
	    "GROUP BY commentstatemetric.value " .
	    "ORDER BY commentstatemetric.value";

	my @metrics = _get_monthly_metrics(12, $query);
	my $months_ref = $metrics[0]->{monthnames};

	# Make sure all enumerated values are catered for.
	my %handled_value = ();
	foreach my $value (@metrics) {
	    $handled_value{$value->{name}} = 1;
	}
	foreach my $value (@{ $metric_config->{values} }) {
	    if (! defined $handled_value{$value}) {
		push @metrics, { name => $value,
				 counts => [0,0,0,0,0,0,0,0,0,0,0,0],
				 monthnames => $months_ref };
	    }
	}

	my $result = { name => $metric_name, results => \@metrics };
	push @results, $result;
    }

    # Get comment thread totals.
    my @total_metrics = ();
    my @thread_total = _get_monthly_metrics(12,
	'SELECT \'Comment Threads\', COUNT(commentstate.id) 
	FROM commentstate
	WHERE commentstate.creation_ts >  ? AND
	      commentstate.creation_ts <= ?');
    push @total_metrics, @thread_total;

    # Get submitted comment totals.
    my @submitted_total = _get_monthly_metrics(12,
	'SELECT \'Submitted Comments\', COUNT(commentstate.id) 
	FROM commentstate, commentdata
	WHERE commentstate.id = commentdata.commentstateid AND
              commentstate.creation_ts >  ? AND
	      commentstate.creation_ts <= ?');
    push @total_metrics, @submitted_total;

    my $result = { name => 'Total', results => \@total_metrics };
    push @results, $result;

    # Close the connection, and check for any database errors.
    Codestriker::DB::DBI->release_connection($dbh, 1);

    return @results;
}

# Returns 12 months of data with a break down of topic metrics.
#
# Returns a collection of the following hash references:
# {
#   name  = the metric name
#   counts = array ref to metric counts per month
#   monthnames = array ref to month names
# }
sub get_topic_metrics {
    my @metrics;

    # Get total.
    my @total = _get_monthly_metrics(12,
	'select \'Total Topics\', count(topic.id) 
	from topic
	where topic.creation_ts >  ? and
	      topic.creation_ts <= ?');

    push @metrics, @total;

    # Get totals for the topic metrics.
    @total = _get_monthly_metrics(12,
	'SELECT topicmetric.metric_name, SUM(topicmetric.value) 
	FROM topicmetric,topic
	WHERE topic.creation_ts >  ? AND
	      topic.creation_ts <= ? AND 
	      topicmetric.topicid = topic.id
	      GROUP BY topicmetric.metric_name
	      ORDER BY topicmetric.metric_name');

    push @metrics, @total;

    # Get totals for the topic user metrics.
    @total = _get_monthly_metrics(12,
	'SELECT topicusermetric.metric_name, SUM(topicusermetric.value) 
	FROM topicusermetric,topic
	WHERE topic.creation_ts >  ? AND
	      topic.creation_ts <= ? AND 
	      topicusermetric.topicid = topic.id
	      GROUP BY topicusermetric.metric_name
	      ORDER BY topicusermetric.metric_name');

    push @metrics, @total;


    return @metrics;
}


# Returns $total_months of data for the given query. The query must return
# name, count collection of rows between two times.
#
# returns a collection of the following hash references
# {
#   name  = the metric name
#   counts = array ref to metric counts per month
#   monthnames = array ref to month names
# }
sub _get_monthly_metrics {
    my ($total_months, $dbi_query_string) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    my @month_dbi_times = _dbi_month_time_stamp($total_months);
    my @month_names = _user_month_name_list($total_months);

    my @metrics;

    # For the past year, get the metrics counts for each month. 
    for (my $month_count = 0;
	 $month_count+1 < @month_dbi_times;
	 ++$month_count) {

	# Do the db query.
	my $comment_counts = $dbh->selectall_arrayref(
	    $dbi_query_string,
	    {}, 
	    $month_dbi_times[$month_count],
	    $month_dbi_times[$month_count+1]);

	foreach my $row (@$comment_counts) {
	    my ($db_metric_name, $db_count) = @$row;

	    my $found = 0;

	    # See if we can find the metric.
	    foreach my $metric (@metrics) {
		if ($metric->{name} eq $db_metric_name) {
		    push @{$metric->{counts}}, $db_count;
		    $found = 1;
		    last;
		}
	    }

	    if ($found == 0) {
		my $metric = 
		    {
		    name=>$db_metric_name,
		    counts=>[],
		    monthnames=>\@month_names
		    };

		# Catch up the collection of counts on any missed months.
		for( my $missingmonths = 0; 
		     $missingmonths < $month_count; 
		     ++$missingmonths) {
		    push @{$metric->{counts}}, 0;
		}

		push @{$metric->{counts}}, $db_count;

		push @metrics, $metric;	    
	    }
	}

	# Add zero's to any metrics not present.
    	foreach my $metric (@metrics) {
	    if (@{$metric->{counts}} eq $month_count) {
		push @{$metric->{counts}}, 0;
	    }
	}
    }

    # Close the connection, and check for any database errors.
    Codestriker::DB::DBI->release_connection($dbh, 1);

    return @metrics;
}

# Return a list of dbi time stamp on 1 month boundaries back for n months. This
# is used to do db queries to get data cut up by month.
sub _dbi_month_time_stamp {
    my ($number_months_back) = @_;

    # Get the start time of this month

    my @month = _add_month(-$number_months_back+1,localtime(time()));

    my @month_dbi_ts;

    for (my $count = 0; $count < $number_months_back +1; ++$count) {
	# Calculate the start of this month dbi string.
	my $month_start = sprintf("%04d-%02d-01 00:00:00", 
	    $month[5]+1900,
	    $month[4]+1);

	push @month_dbi_ts, $month_start;

	@month = _add_month(1, @month);
    }
    
    return @month_dbi_ts; 
}

# Return a list of user displayable time stamps on 1 month bondaries
# back for n months.
sub _user_month_name_list {
    my ($number_months_back) = @_;

    # Get the start time of this month.
    my @month = _add_month(-$number_months_back+1,localtime(time()));

    my @month_names;

    for (my $count = 0; $count < $number_months_back; ++$count) {
	my $month_name = $Codestriker::short_months[$month[4]] .
	    " " . ($month[5]+1900);
	 
	push @month_names, $month_name;

	@month = _add_month(1, @month);
    }
    
    return @month_names; 
}


# Add or substracts count months on to a time array.
sub _add_month {
    my ($count,@time) = @_;

    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = @time;
    
    if ($count > 0) {
	for (my $i = 0; $i < $count; ++$i) {
	    # Calculate the end of this month dbi string.
	    ++$mon;

	    if ($mon >= 12) {
		$mon = 0;
		++$year;
    	    }
	}
    }
    elsif ($count < 0) {
	for (my $i = $count; $i < 0; ++$i) {
	    # Calculate the end of this month dbi string.
	    --$mon;

	    if ($mon < 0) {
		$mon = 11;
		--$year;
    	    }
	}
    }

    $time[4] = $mon;
    $time[5] = $year;

    return @time;
}

1;
