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

$table{topic} =
    'id int NOT NULL,
     author varchar(255) NOT NULL,
     title varchar(255) NOT NULL,
     description text NOT NULL,
     document text NOT NULL,
     state smallint NOT NULL,
     creation_ts timestamp NOT NULL,
     modified_ts timestamp NOT NULL,
     version int NOT NULL,
     PRIMARY KEY (id)';

$index{topic} = "CREATE INDEX author_idx ON topic(author)";

$table{comment} =
    'topicid int NOT NULL,
     commentfield text NOT NULL,
     author varchar(255) NOT NULL,
     line int NOT NULL,
     creation_ts timestamp NOT NULL';

$index{comment} = "CREATE INDEX comment_tid_idx ON comment(topicid)";
     
$table{participant} =
    'email varchar(255) NOT NULL,
     topicid int NOT NULL,
     type smallint NOT NULL,
     state smallint NOT NULL,
     modified_ts timestamp NOT NULL,
     version int NOT NULL,
     PRIMARY KEY (topicid, email)';

$index{participant} =
    "CREATE INDEX participant_tid_idx ON participant(topicid)";

$table{topicbug} =
    'bugid int NOT NULL,
     topicid int NOT NULL,
     PRIMARY KEY (topicid, bugid)';

$index{topicbug} = "CREATE INDEX topicbug_tid_idx ON topicbug(topicid)";

$table{file} =
    'topicid int NOT NULL,
     sequence smallint NOT NULL,
     filename text NOT NULL,
     topicoffset int NOT NULL,
     revision varchar(100) NOT NULL,
     binaryfile smallint NOT NULL,
     diff text,
     PRIMARY KEY (topicid, sequence)';

$index{file} = "CREATE INDEX file_tid_idx ON file(topicid)";

$table{version} =
    'id text NOT NULL,
     sequence smallint NOT NULL';

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
$max_sequence++;

if (!$found) {
    my $insert = $dbh->prepare_cached('INSERT INTO version (id, sequence) ' .
				      'VALUES (?, ?)');
    $insert->execute($Codestriker::VERSION, $max_sequence);
}

$dbh->commit;
$dbh->disconnect;


