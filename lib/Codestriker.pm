###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Main package which contains a reference to all configuration variables.

package Codestriker;

use strict;

use Time::Local;

# Export codestriker.conf configuration variables.
use vars qw ( $mailhost $use_compression $gzip $cvs $vss $bugtracker
	      @valid_repositories $default_topic_create_mode $default_tabwidth
	      $file_reviewer $db $dbuser $dbpasswd $codestriker_css
	      $NORMAL_MODE $COLOURED_MODE $COLOURED_MONO_MODE $topic_states
	      $bug_db $bug_db_host $bug_db_name $bug_db_password $bug_db_user
	      $lxr_map $allow_comment_email $default_topic_br_mode
	      $allow_delete $allow_searchlist $allow_repositories
              $allow_projects $antispam_email $VERSION $title $BASEDIR
	      @metrics_schema
	      );

# Version of Codestriker.
$Codestriker::VERSION = "1.8.0pre1";

# Default title to display on each Codestriker screen.
$Codestriker::title = "Codestriker $Codestriker::VERSION";

# The maximum size of a diff file to accept.  At the moment, this is 20Mb.
$Codestriker::DIFF_SIZE_LIMIT = 20000 * 1024;

# Indicate what base directory Codestriker is running in.  This may be set
# in cgi-bin/codestriker.pl, depending on the environment the script is
# running in.  By default, assume the script is running in the cgi-bin
# directory (this is not the case for Apache2 + mod_perl).
$Codestriker::BASEDIR = "..";

# Error codes.
$Codestriker::OK = 1;
$Codestriker::STALE_VERSION = 2;
$Codestriker::INVALID_TOPIC = 3;
$Codestriker::INVALID_PROJECT = 4;
$Codestriker::DUPLICATE_PROJECT_NAME = 5;
$Codestriker::UNSUPPORTED_OPERATION = 6;
$Codestriker::DIFF_TOO_BIG = 7;

# Revision number constants used in the filetable with special meanings.
$Codestriker::ADDED_REVISION = "1.0";
$Codestriker::REMOVED_REVISION = "0.0";
$Codestriker::PATCH_REVISION = "0.1";

# Participant type constants.
$Codestriker::PARTICIPANT_REVIEWER = 0;
$Codestriker::PARTICIPANT_CC = 1;

# Default email context to use.
$Codestriker::EMAIL_CONTEXT = 8;

# Valid comment states, the only one that is special is the submitted state.
$Codestriker::COMMENT_SUBMITTED = 0;

# Day strings
@Codestriker::days = ("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
		      "Friday", "Saturday");

# Month strings
@Codestriker::months = ("January", "February", "March", "April", "May", "June",
			"July", "August", "September", "October", "November",
			"December");

# Short day strings
@Codestriker::short_days = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");

# Short month strings
@Codestriker::short_months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
			      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");



# name => The short name of the metric. This name will be used in the SQL table, in the data download, and in the input tables.
#
# description => The long description of the item. Displayed as online help.
#
# enabled=> If 1, the metrics are enabled by default on new installs of codestriker. After 
#             the system has been configured, it is up to the local admin. 
#
# Scope => This will be "topic", "reviewer","author".
#	    A "topic" metric that has a 1 to 1 relationship with the topic itself.
#           If it is not a topic metric, it is a kind  of user metric. User metrics 
#           have a 1-1 relationship with each user in the topic. If the type is 
#           reviewer, it is only needed by a user that is a reviewer (but not author), 
#           of the topic. If the type is author, it is only needed by the author of the 
#           metric, and if it is participants, it is needed by all users regardless 
#           of the role.
#
# filter => The type of data being stored. "hours" or "count". Data will not be stored to 
#           the database if it does not pass the format expected for the filter type.

@metrics_schema = 
( 
  # planning time
  {
  name=>"entry time",
  description=>"Work hours spent by the inspection leader to check that entry conditions are met, and to work towards meeting them",
  enabled=>0,
  scope=>"author",
  filter=>"hours"
  },
  {
  name=>"kickoff time",
  description=>"Total work hours used per individual for the kickoff meeting and for planning of the kickoff meeting.",
  scope=>"participant",
  enabled=>1,
  filter=>"hours"
  },
  {
  name=>"planning time",
  description=>"Total work hours used to create the inspection master plan.",
  scope=>"author",
  enabled=>0,
  filter=>"hours"
  },

  # checking time
  {
  name=>"checking time",
  description=>"The total time spent checking the topic.",
  scope=>"participant",
  enabled=>1, 
  filter=>"hours"
  },
  {
  name=>"lines studied",
  description=>"The number of lines which have been closly scrutinized at or near optimum checking rate",
  scope=>"participant",
  enabled=>0,
  filter=>"count"
  },
  {
  name=>"lines scanned",
  description=>"The number of lines which have been looked at higher then the optimum checking rate",
  scope=>"participant",
  enabled=>0,
  filter=>"count"
  },
  {
  name=>"studied time",
  description=>"The time in hours spent closly scrutinized at or near optimum checking rate",
  scope=>"participant",
  enabled=>0,
  filter=>"hours"
  },
  {
  name=>"scanned time",
  description=>"The time in hours spent looking at the topic at higher then the optimum checking rate",
  scope=>"participant",
  enabled=>0,
  filter=>"hours"
  },

  # logging meeting time.
  {
  name=>"logging meeting duration",
  description=>"The wall clock time of the logging meeting.",
  scope=>"topic",
  enabled=>1, 
  filter=>"hours"
  },
  {
  name=>"logging meeting logging duration",
  description=>"The wall clock time spent reporting issues and searching for new issues.",
  scope=>"topic",
  enabled=>0,
  filter=>"hours"
  },
  {
  name=>"logging meeting discussion duration",
  description=>"The wall clock time spent not reporting issues and searching for new issues.",
  scope=>"topic",
  enabled=>0,
  filter=>"hours"
  },
  {
  name=>"logging meeting logging time",
  description=>"The total time spent reporting issues and searching for new issues.",
  scope=>"participant",
  enabled=>0,
  filter=>"hours"
  },
  {
  name=>"logging meeting discussion time",
  description=>"The total time spent not reporting issues and searching for new issues.",
  scope=>"participant",
  enabled=>0,
  filter=>"hours"
  },
  ,
  {
  name=>"logging meeting new issues logged",
  description=>"The total number of issues that were not noted before the meeting and found during the meeting.",
  scope=>"topic",
  enabled=>0,
  filter=>"count"
  },

  # editing

  {
  name=>"edit time",
  description=>"The total time spent editing all items",
  scope=>"author",
  enabled=>0,
  filter=>"hours"
  },
  {
  name=>"follow up time",
  description=>"The total time spent by the leader to check exit criteria and do exit activities.",
  scope=>"author",
  enabled=>0,
  filter=>"hours"
  },

  {
  name=>"exit time",
  description=>"The total time spent by the leader to check exit criteria and do exit activities.",
  scope=>"author",
  enabled=>0,
  filter=>"hours"
  },

  {
  name=>"correct fix rate",
  description=>"The percentage of edit corrections attempts with correct fix a defect and not introduce new defects.",
  scope=>"author",
  enabled=>0,
  filter=>"percent"
  },

);


# Initialise codestriker, by loading up the configuration file and exporting
# those values to the rest of the system.
sub initialise($$) {
    my ($type, $basedir) = @_;

    $BASEDIR = $basedir;

    # Load up the configuration file.
    my $config = "$BASEDIR/codestriker.conf";
    if (-f $config) {
	do $config;
    } else {
	die("Couldn't find configuration file: \"$config\".\n<BR>" .
	    "Please fix the \$config setting in codestriker.pl.");
    }
}

# Returns the current time in a format suitable for a DBI timestamp value.
sub get_timestamp($$) {
    my ($type, $time) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime($time);
    $year += 1900;

    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $mon+1, $mday,
		   $hour, $min, $sec);
}

# Given a database formatted timestamp, output it in a human-readable form.
sub format_timestamp($$) {
    my ($type, $timestamp) = @_;

    if ($timestamp =~ /(\d\d\d\d)\-(\d\d)\-(\d\d) (\d\d):(\d\d):(\d\d)/ ||
	$timestamp =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/) {
	my $time_value = Time::Local::timelocal($6, $5, $4, $3, $2-1, $1);
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    localtime($time_value);
	$year += 1900;
	return sprintf("$Codestriker::days[$wday] " .
		       "$Codestriker::months[$mon] $mday , $year %02d:%02d:%02d ",
		       $hour, $min, $sec);
    } else {
	return $timestamp;
    }
}

# Given a database formatted timestamp, output it in a short,
# human-readable form.
sub format_short_timestamp($$) {
    my ($type, $timestamp) = @_;

    if ($timestamp =~ /(\d\d\d\d)\-(\d\d)\-(\d\d) (\d\d):(\d\d):(\d\d)/ ||
	$timestamp =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/) {
	my $time_value = Time::Local::timelocal($6, $5, $4, $3, $2-1, $1);
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    localtime($time_value);
	$year += 1900;
	return sprintf("%02d:%02d:%02d $Codestriker::short_days[$wday], " .
		       "$mday $Codestriker::short_months[$mon], $year",
		       $hour, $min, $sec);
    } else {
	return $timestamp;
    }
}

# Given a database formatted timestamp, output it in a short,
# human-readable date only form.
sub format_date_timestamp($$) {
    my ($type, $timestamp) = @_;

    if ($timestamp =~ /(\d\d\d\d)\-(\d\d)\-(\d\d) (\d\d):(\d\d):(\d\d)/ ||
	$timestamp =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/) {
	my $time_value = Time::Local::timelocal($6, $5, $4, $3, $2-1, $1);
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
	    localtime($time_value);
	$year += 1900;
	return "$Codestriker::short_days[$wday] $Codestriker::short_months[$mon] $mday, $year";
		      
    } else {
	return $timestamp;
    }
}


# Given an email string, replace it in a non-SPAM friendly form.
# sits@users.sf.net -> sits@us...
sub make_antispam_email($$) {
    my ($type, $email) = @_;

    $email =~ s/([0-9A-Za-z\._]+@[0-9A-Za-z\._]{3})[0-9A-Za-z\._]+/$1\.\.\./g;
    return "$email";
}

sub filter_email {
    my ($type, $email) = @_;
    
    if ($Codestriker::antispam_email) {
	$email = $type->make_antispam_email($email);
    }
    
    return $email;
}

    
1;


