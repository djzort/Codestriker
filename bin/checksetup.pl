#!/usr/bin/perl -w

###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# This script is similar to bugzilla's checksetup.pl.  It can be run whenever
# you like, but ideally should be done after every upgrade.  Currently the
# module does the following:
#
# - check for the required perl modules
# - creates the database "codestriker" if the database does not exist
# - creates the tables inside the database if they don't exist
# - authomatically changes the table definitions of older codestriker
#   installations (including versions <= 1.4.X).

use strict;

use lib '../lib';
use Codestriker::DB::DBI;

# Initialise Codestriker, load up the configuration file.
Codestriker->initialise();

# Obtain a database connection.
my $dbh = Codestriker::DB::DBI->get_connection();

# Record of all of the table definitions which need to be created.
my %table;

# Record of index statements required.
my %index;

# The database type for storing topic text.  It needs to support large
# sizes.  By default, this is "text", which is fine for recent versions of
# PostgreSQL.  For MySQL, this needs to be "mediumtext".
my $text_type = "text";
if ($Codestriker::db =~ /^DBI:mysql/i) {
    $text_type = "mediumtext";
}

$table{topic} =
    "id int NOT NULL,
     author varchar(255) NOT NULL,
     title varchar(255) NOT NULL,
     description text NOT NULL,
     document $text_type NOT NULL,
     state smallint NOT NULL,
     creation_ts timestamp NOT NULL,
     modified_ts timestamp NOT NULL,
     version int NOT NULL,
     PRIMARY KEY (id)";

$index{topic} = "CREATE INDEX author_idx ON topic(author)";

$table{comment} =
    "topicid int NOT NULL,
     commentfield text NOT NULL,
     author varchar(255) NOT NULL,
     line int NOT NULL,
     creation_ts timestamp NOT NULL";

$index{comment} = "CREATE INDEX comment_tid_idx ON comment(topicid)";
     
$table{participant} =
    "email varchar(255) NOT NULL,
     topicid int NOT NULL,
     type smallint NOT NULL,
     state smallint NOT NULL,
     modified_ts timestamp NOT NULL,
     version int NOT NULL,
     PRIMARY KEY (topicid, email, type)";

$index{participant} =
    "CREATE INDEX participant_tid_idx ON participant(topicid)";

$table{topicbug} =
    "bugid int NOT NULL,
     topicid int NOT NULL,
     PRIMARY KEY (topicid, bugid)";

$index{topicbug} = "CREATE INDEX topicbug_tid_idx ON topicbug(topicid)";

$table{file} =
    "topicid int NOT NULL,
     sequence smallint NOT NULL,
     filename text NOT NULL,
     topicoffset int NOT NULL,
     revision varchar(100) NOT NULL,
     binaryfile smallint NOT NULL,
     diff $text_type,
     PRIMARY KEY (topicid, sequence)";

$index{file} = "CREATE INDEX file_tid_idx ON file(topicid)";

$table{version} =
    "id text NOT NULL,
     sequence smallint NOT NULL";

# MySQL specific function adapted from Bugzilla.
sub get_field_def ($$)
{
    my ($table, $field) = @_;
    my $sth = $dbh->prepare("SHOW COLUMNS FROM $table");
    $sth->execute;

    while (my $ref = $sth->fetchrow_arrayref) {
        next if $$ref[0] ne $field;
        return $ref;
   }
}

# Create any missing tables.
my @existing_tables = map { $_ =~ s/.*\.//; $_ } $dbh->tables;

foreach my $tablename (keys %table) {
    next if grep /^$tablename$/, @existing_tables;
    print "Creating table $tablename...\n";
    
    my $fields = $table{$tablename};
    $dbh->do("CREATE TABLE $tablename (\n$fields\n)") ||
	die "Could not create table $tablename: " . $dbh->errstr;

    if (defined $index{$tablename}) {
	$dbh->do($index{$tablename}) ||
	    die "Could not create indexes for table $tablename: " .
	    $dbh->errstr;
    }
}

# If we are using MySQL, and we are upgrading from a version of the database
# which used "text" instead of "mediumtext" for certain fields, update the
# appropriate table columns.
if ($Codestriker::db =~ /^DBI:mysql/i) {
    # Check that document field in topic is up-to-date.
    my $ref = get_field_def("topic", "document");
    if ($$ref[1] ne $text_type) {
	print "Updating topic table for document field to be $text_type...\n";
	$dbh->do("ALTER TABLE topic CHANGE document document $text_type") ||
	    die "Could not alter topic table: " . $dbh->errstr;
    }

    # Check that the diff field in file is up-to-date.
    $ref = get_field_def("file", "diff");
    if ($$ref[1] ne $text_type) {
	print "Updating file table for diff field to be $text_type...\n";
	$dbh->do("ALTER TABLE file CHANGE diff diff $text_type") ||
	    die "Could not alter file table: " . $dbh->errstr;
    }
}
    
# Insert the version number into the table, if required.
my $stmt = $dbh->prepare_cached('SELECT id, sequence FROM version');
$stmt->execute();
my $found = 0;
my $max_sequence = 0;
my @data;
while (@data = $stmt->fetchrow_array()) {
    my ($id, $seq) = @data;
    $max_sequence = $seq if $seq > $max_sequence;
    if ($id eq $Codestriker::VERSION) {
	$found = 1;
	last;
    }
}
$stmt->finish();
$max_sequence++;

if (!$found) {
    my $insert = $dbh->prepare_cached('INSERT INTO version (id, sequence) ' .
				      'VALUES (?, ?)');
    $insert->execute($Codestriker::VERSION, $max_sequence);
}

$dbh->commit;
$dbh->disconnect;


