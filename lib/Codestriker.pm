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
use vars qw ( $mailhost $use_compression $gzip $cvs $bugtracker
	      @valid_repositories $default_topic_create_mode $default_tabwidth
	      $file_reviewer $db $dbuser $dbpasswd $codestriker_css
	      $NORMAL_MODE $COLOURED_MODE $COLOURED_MONO_MODE $topic_states
	      $bug_db $bug_db_host $bug_db_name $bug_db_password $bug_db_user
	      $lxr_map
	      $allow_delete $allow_searchlist $allow_repositories
              $allow_projects $antispam_email $VERSION $BASEDIR
	      );

# Version of Codestriker.
$Codestriker::VERSION = "1.7.2";

# The maximum size of a diff file to accept.  At the moment, this is 10Mb.
$Codestriker::DIFF_SIZE_LIMIT = 10000 * 1024;

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

# Valid comment states.
$Codestriker::COMMENT_SUBMITTED = 0;
$Codestriker::COMMENT_INVALID = 1;
$Codestriker::COMMENT_COMPLETED = 2;

# Textual representations of the above states.
@Codestriker::comment_states = ("Submitted", "Invalid", "Completed");

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
	return sprintf("%02d:%02d:%02d $Codestriker::days[$wday], $mday " .
		       "$Codestriker::months[$mon], $year",
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

# Given an email string, replace it in a non-SPAM friendly form.
# sits@users.sf.net -> sits@us...
sub make_antispam_email($$) {
    my ($type, $email) = @_;

    $email =~ s/([0-9A-Za-z\._]+@[0-9A-Za-z\._]{3})[0-9A-Za-z\._]+/$1\.\.\./g;
    return "$email";
}

1;


