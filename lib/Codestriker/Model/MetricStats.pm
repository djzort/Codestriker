###############################################################################
# Copyright (c) 2003 Jason Remillard.  All rights reserved.
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling metrics reports. This object is not an object, it
# is a normal module.

package Codestriker::Model::MetricStats;

use strict;
use warnings;

use Codestriker::DB::DBI;

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
	my ($name, $date, $count) = @$row;

	my $metrics = 
	{
	    name=>$name,
	    date_last_authored=>Codestriker->format_date_timestamp($date),
	    date_last_participated=>'',
	    total_topics=>$count
	};

	push(@users_metrics, $metrics);
    }
 
    # Get the list of participants from all these topics.
    my $participant_list = $dbh->selectall_arrayref(
	    'SELECT comment.author, MAX(topic.modified_ts), COUNT(DISTINCT topic.id)
	     FROM comment, commentstate, topic 
	     WHERE topic.modified_ts >= ? AND 
		   topic.id = commentstate.topicid AND 
		   topic.author <> comment.author AND
		   comment.commentstateid = commentstate.id
	     GROUP BY comment.author
	     ORDER BY 2 desc',{}, $date);
     
    foreach my $row (@$participant_list) {
	my ($name, $date, $count) = @$row;

	my $found = 0;
	foreach my $user (@users_metrics) {
	    if ($user->{name} eq $name) {
		$user->{date_last_participated} = 
		    Codestriker->format_date_timestamp($date);
		$user->{total_topics} += $count;
		$found = 1;
	    }
	}

	if ($found == 0) {
	    my $metrics = 
	    {
		name=>$name,
		date_last_authored=>'',
		date_last_participated=>Codestriker->format_date_timestamp($date),
		total_topics=>$count
	    };

	    push( @users_metrics, $metrics);
	}
    }

    return @users_metrics;
}


# Returns a list of all the topic ids in the database.
sub get_topic_ids {
    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Get the list of authors.
    my $topicid_list  = $dbh->selectall_arrayref(
	    'SELECT id FROM topic ORDER BY creation_ts');

    return @$topicid_list;

}

# Returns in a hash the column names for the raw metric download feature.
sub get_download_headers {
    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    my @base_headers = qw(
	id
	author
	title
	state
	creation
	project	
	);

    # Comment counts.
    my $comment_states = $dbh->selectall_arrayref(
	    'SELECT distinct state 
	     FROM commentstate 
	     ORDER BY state
	    ');


    my $comment_state_count = scalar(@Codestriker::comment_states);

    # States in db may be larger than current configuration.
    if (@$comment_states > 0 &&
	$comment_states->[-1]->[0] >= $comment_state_count) {
	$comment_state_count = ($comment_states->[-1]->[0])+1;
    }

    my @state_headers;

    for(my $state = 0; $state < $comment_state_count; ++$state) {
	if ($state < @Codestriker::comment_states) {
	    push @state_headers, $Codestriker::comment_states[$state];
	} 
	else {
	    push @state_headers, $state;
	}
    }

    my @topic_metric_headers;

    # Topic metrics counts
    my $topic_metrics = $dbh->selectall_arrayref(
	    'SELECT DISTINCT metric_name 
	     FROM topic_metric
	     ORDER by metric_name
	    ');

    foreach my $metric (@$topic_metrics) {
	push @topic_metric_headers, $metric->[0];
    }

    my @topic_user_metric_headers;

    # User topic metrics counts.
    my $user_topic_metrics  = $dbh->selectall_arrayref(
	    'SELECT DISTINCT metric_name 
	     FROM topic_user_metric
	     ORDER by metric_name
	    ');

    foreach my $metric (@$user_topic_metrics) {
	push @topic_user_metric_headers, $metric->[0];
    }
    
    my $headers = 
    {
	base=>\@base_headers,
	state=>\@state_headers,
	topic=>\@topic_metric_headers,
	user=>\@topic_user_metric_headers
    };

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
	    SELECT topic.id, topic.author, topic.title, topic.state, topic.creation_ts, project.name 
	    FROM topic, project
	    WHERE topic.id = ? AND topic.projectid = project.id',{}, $topicid);


    if ($basic_topic_info[3] < @Codestriker::topic_states) {
	$basic_topic_info[3] = @Codestriker::topic_states[$basic_topic_info[3]];
    }

    $basic_topic_info[4] =
	Codestriker->format_date_timestamp($basic_topic_info[4]);

    my @row;

    push @row,@basic_topic_info;

    # Get comment state counts.
    my $comment_states = $dbh->selectall_arrayref(
	    'SELECT state, COUNT(id)
	     FROM commentstate 
	     WHERE topicid = ?
	     GROUP BY state
	    ',{}, $topicid);
    
    for (my $commentindex = 0; 
	 $commentindex < scalar(@{$headers->{state}}); 
	 ++$commentindex) {
	my $count = 0;

	foreach my $row ( @$comment_states ) {
	    $count = $row->[1] if ($row->[0] == $commentindex);
	}

	push @row, $count;
    } 


    # Get the topic metrics.
    my $topic_metrics = $dbh->selectall_arrayref(
	    'SELECT metric_name, sum(value)
	     FROM topic_metric 
	     WHERE topicid = ?
	     GROUP BY metric_name
	    ',{}, $topicid);
    
    for (my $index = 0; $index < scalar(@{$headers->{topic}}); ++$index) {
	my $count = 0;

	foreach my $row ( @$topic_metrics ) {
	    $count = $row->[1] if ($row->[0] eq $headers->{topic}->[$index]);
	}

	push @row, $count;
    } 

    # Get the user metrics.
    my $user_metrics = $dbh->selectall_arrayref(
	    'SELECT metric_name, sum(value)
	     FROM topic_user_metric 
	     WHERE topicid = ?
	     GROUP BY metric_name
	    ',{}, $topicid);
    
    for (my $index = 0; $index < scalar(@{$headers->{user}}); ++$index) {
	my $count = 0;

	foreach my $row ( @$user_metrics ) {
	    $count = $row->[1] if ($row->[0] eq $headers->{user}->[$index]);
	}

	push @row, $count;
    } 

    return @row;
}

# Returns 12 months of data with a break down of comment types.
#
# returns a collection of the following hash references
# {
#   name  = the metric name
#   counts = array ref to metric counts per month
#   monthnames = array ref to month names
# }
sub get_comment_metrics {
    my $query = 
	'SELECT commentstate.state, COUNT(commentstate.id) 
	FROM commentstate
	WHERE commentstate.creation_ts >  ? AND
   	      commentstate.creation_ts <= ?
	GROUP BY commentstate.state
	ORDER BY commentstate.state';

    my @metrics = _get_monthly_metrics(12, $query);

    foreach my $metric (@metrics) {
	if ( $metric->{name} < @Codestriker::comment_states) {
	    $metric->{name} = $Codestriker::comment_states[$metric->{name}];
	}
    }

    # Get totals.
    my @total = _get_monthly_metrics(12,
	'SELECT \'Total Comments\', COUNT(commentstate.id) 
	FROM commentstate
	WHERE commentstate.creation_ts >  ? AND
	      commentstate.creation_ts <= ?');

    push @metrics, @total;

    return @metrics;
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
	'SELECT topic_metric.metric_name, SUM(topic_metric.value) 
	FROM topic_metric,topic
	WHERE topic.creation_ts >  ? AND
	      topic.creation_ts <= ? AND 
	      topic_metric.topicid = topic.id
	      GROUP BY topic_metric.metric_name
	      ORDER BY topic_metric.metric_name');

    push @metrics, @total;

    # Get totals for the topic metrics.
    @total = _get_monthly_metrics(12,
	'SELECT topic_user_metric.metric_name, SUM(topic_user_metric.value) 
	FROM topic_user_metric,topic
	WHERE topic.creation_ts >  ? AND
	      topic.creation_ts <= ? AND 
	      topic_user_metric.topicid = topic.id
	      GROUP BY topic_user_metric.metric_name
	      ORDER BY topic_user_metric.metric_name');

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

    return @metrics;
}

# Return a list of dbi time stamp on 1 month bondaries back for n months. This
# is used to do db queries to get data cut up by month.
sub _dbi_month_time_stamp {
    my ($number_months_back) = @_;

    # Get the start time of this month

    my @month = _add_month(-$number_months_back+1,localtime(time()));

    my @month_dbi_ts;

    for (my $count = 0; $count < $number_months_back +1; ++$count) {
	# Calculate the start of this month dbi string.
	my $month_start = sprintf("%04d-%02d-1 00:00:00", 
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
