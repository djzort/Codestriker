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
use CGI::Carp 'fatalsToBrowser';

# Export codestriker.conf configuration variables.
use vars qw ( $datadir $sendmail $use_compression $gzip $bugtracker
	      $cvsviewer $cvsrep $cvscmd $codestriker_css
	      $default_topic_create_mode $default_tabwidth
	      $NORMAL_MODE $COLOURED_MODE $COLOURED_MONO_MODE );

# Revision number constants used in the filetable with special meanings.
$Codestriker::ADDED_REVISION = "1.0";
$Codestriker::REMOVED_REVISION = "0.0";
$Codestriker::PATCH_REVISION = "0.1";

# Default email context to use.
$Codestriker::EMAIL_CONTEXT = 8;

# Day strings
my @days = ("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
	    "Saturday");

# Month strings
my @months = ("January", "Februrary", "March", "April", "May", "June", "July",
	      "August", "September", "October",	"November", "December");

# Initialise codestriker, by loading up the configuration file and exporting
# those values to the rest of the system.
sub initialise($) {
    my ($type) = @_;

    # Load up the configuration file.
    my $config = "/var/www/codestriker/codestriker.conf";
    if (-f $config) {
	do $config;
    } else {
	die("Couldn't find configuration file: \"$config\".\n<BR>" .
	    "Please fix the \$config setting in codestriker.pl.");
    }
}

# Returns the current time in a format suitable for a DBI timestamp value.
sub get_current_timestamp($) {
    my ($type) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime(time);
    $year += 1900;

    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday,
		   $hour, $min, $sec);
}

# Given a database formatted timestamp, output it in a human-readable form.
sub format_timestamp($$) {
    my ($type, $timestamp) = @_;

    if ($timestamp =~ /(\d\d\d\d)\-(\d\d)\-(\d\d) (\d\d):(\d\d):(\d\d)/) {
	my $time_value = Time::Local::timelocal($6, $5, $4, $3, $2, $1);
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    localtime($time_value);
	$year += 1900;
	return sprintf("%02d:%02d:%02d $days[$wday], $mday $months[$mon], " .
		       "$year", $hour, $min, $sec);
    } else {
	return $timestamp;
    }
}

1;


