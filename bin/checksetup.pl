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
#   installations, and does data migration automatically.

use strict;

use lib '../lib';
use Codestriker::DB::DBI;
use Codestriker::Action::SubmitComment;
use Codestriker::Repository::RepositoryFactory;
use Codestriker::FileParser::Parser;

# Initialise Codestriker, load up the configuration file.
Codestriker->initialise();

# Indicate which modules are required for codestriker (this code is
# completely stolen more-or-less verbatim from Bugzilla)
my $modules = [ 
    { 
        name => 'LWP::UserAgent', 
        version => '0' 
    }, 
    { 
        name => 'CGI', 
        version => '2.56' 
    }, 
    { 
        name => 'CGI::Carp', 
        version => '0' 
    }, 
    { 
        name => 'Net::SMTP', 
        version => '0' 
    }, 
    { 
        name => 'DBI', 
        version => '1.13' 
    }, 
    { 
        name => 'Template', 
        version => '2.07' 
    }
];

my %missing = ();
foreach my $module (@{$modules}) {
    unless (have_vers($module->{name}, $module->{version})) { 
        $missing{$module->{name}} = $module->{version};
    }
}

# vers_cmp is adapted from Sort::Versions 1.3 1996/07/11 13:37:00 kjahds,
# which is not included with Perl by default, hence the need to copy it here.
# Seems silly to require it when this is the only place we need it...
sub vers_cmp {
  if (@_ < 2) { die "not enough parameters for vers_cmp" }
  if (@_ > 2) { die "too many parameters for vers_cmp" }
  my ($a, $b) = @_;
  my (@A) = ($a =~ /(\.|\d+|[^\.\d]+)/g);
  my (@B) = ($b =~ /(\.|\d+|[^\.\d]+)/g);
  my ($A,$B);
  while (@A and @B) {
    $A = shift @A;
    $B = shift @B;
    if ($A eq "." and $B eq ".") {
      next;
    } elsif ( $A eq "." ) {
      return -1;
    } elsif ( $B eq "." ) {
      return 1;
    } elsif ($A =~ /^\d+$/ and $B =~ /^\d+$/) {
      return $A <=> $B if $A <=> $B;
    } else {
      $A = uc $A;
      $B = uc $B;
      return $A cmp $B if $A cmp $B;
    }
  }
  @A <=> @B;
}

# This was originally clipped from the libnet Makefile.PL, adapted here to
# use the above vers_cmp routine for accurate version checking.
sub have_vers {
  my ($pkg, $wanted) = @_;
  my ($msg, $vnum, $vstr);
  no strict 'refs';
  printf("Checking for %15s %-9s ", $pkg, !$wanted?'(any)':"(v$wanted)");

  eval { my $p; ($p = $pkg . ".pm") =~ s!::!/!g; require $p; };

  $vnum = ${"${pkg}::VERSION"} || ${"${pkg}::Version"} || 0;
  $vnum = -1 if $@;

  if ($vnum eq "-1") { # string compare just in case it's non-numeric
    $vstr = "not found";
  }
  elsif (vers_cmp($vnum,"0") > -1) {
    $vstr = "found v$vnum";
  }
  else {
    $vstr = "found unknown version";
  }

  my $vok = (vers_cmp($vnum,$wanted) > -1);
  print ((($vok) ? "ok: " : " "), "$vstr\n");
  return $vok;
}

# Output any modules which may be missing.
if (%missing) {
    print "\n\n";
    print "Codestriker requires some Perl modules which are either missing\n",
    "from your system, or the version on your system is too old.\n",
    "They can be installed by running (as root) the following:\n";
    foreach my $module (keys %missing) {
        print "   perl -MCPAN -e 'install \"$module\"'\n";
        if ($missing{$module} > 0) {
            print "   Minimum version required: $missing{$module}\n";
        }
    }
    print "\n";
    exit;
}


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
     repository text,
     PRIMARY KEY (id)";

$index{topic} = "CREATE INDEX author_idx ON topic(author)";

$table{comment} =
    "topicid int NOT NULL,
     commentstateid int NOT NULL,
     commentfield text NOT NULL,
     author varchar(255) NOT NULL,
     creation_ts timestamp NOT NULL";

$index{comment} = "CREATE INDEX comment_tid_idx ON comment(topicid)";

$table{commentstate} =
    "id int NOT NULL auto_increment,
     topicid int NOT NULL,
     fileline int NOT NULL,
     filenumber int NOT NULL,
     filenew smallint NOT NULL,
     state smallint NOT NULL,
     version int NOT NULL,
     creation_ts timestamp NOT NULL,
     modified_ts timestamp NOT NULL,
     PRIMARY KEY (id)";

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

$table{delta} =
    "topicid int NOT NULL,
     file_sequence smallint NOT NULL,
     delta_sequence smallint NOT NULL,
     old_linenumber int NOT NULL,
     new_linenumber int NOT NULL,
     deltatext $text_type NOT NULL,
     description $text_type NOT NULL,
     PRIMARY KEY (topicid, delta_sequence)";

$index{delta} = "CREATE INDEX delta_fid_idx ON delta(topicid)";

$table{version} =
    "id text NOT NULL,
     sequence smallint NOT NULL";

# Add a field to a specific table.  If the field already exists, then catch
# the error and continue silently.
sub add_field ($$$)
{
    my ($table, $field, $definition) = @_;
    my $rc = 0;

    # Perform this operation in a separate connection, so any errors won't
    # affect the outer transaction.
    my $local_dbh = Codestriker::DB::DBI->get_connection();
    $local_dbh->{RaiseError} = 0;
    $local_dbh->{PrintError} = 0;
    if (! $local_dbh->do("ALTER TABLE $table ADD COLUMN $field $definition")) {
	# Most likely, the column already exists, silently continue.
    } else {
	print "Added new field $field to table $table.\n";
	$rc = 1;
    }
    Codestriker::DB::DBI->release_connection($local_dbh, 1);
    return $rc;
}

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

# Add appropriate fields to the database tables as things have evolved.
# Make sure the database is committed before proceeding.
Codestriker::DB::DBI->release_connection($dbh, 1);
$dbh = Codestriker::DB::DBI->get_connection();

add_field('topic', 'repository', 'text');

my $stmt;

# Ensure all comments are accounted for in the commentstate table.  Note,
# since MySQL doesn't have nested statements, this has to be done the hard
# way.
my $added_comment_fileline = 0;
my $added_commentstate_filenumber = 0;
if ($added_comment_fileline) {
    $stmt = $dbh->prepare_cached('SELECT DISTINCT topicid, line FROM comment');
    $stmt->execute();
    while (my ($topicid, $line) = $stmt->fetchrow_array()) {

	# Check if there is an associated record in the commentstate
	# table, and if not, create it.
	my $check = $dbh->prepare_cached('SELECT COUNT(*) FROM commentstate ' .
					 'WHERE topicid = ? AND line = ?');
	$check->execute($topicid, $line);
	my ($count) = $check->fetchrow_array();
	$check->finish();
	next if ($count != 0);
	
	# Associated commentstate record doesn't exist, create it.
	# All the column values will be filled in the next block of code.
	print "Creating commentstate row for topicid $topicid line $line\n";
	my $insert = $dbh->prepare_cached('INSERT INTO commentstate ' .
					  '(topicid, line, state, filename, ' .
					  'filenumber, fileline, version) ' .
					  'VALUES (?, ?, ?, ?, ?, ?)');
	$insert->execute($topicid, $line, $Codestriker::COMMENT_SUBMITTED,
			 "", 0, 0, 0);
	$insert->finish();
    }
    $stmt->finish();
}

# If the "fileline" column was added to the comment table, need to migrate
# all comment offsets to filenumber/fileline reporting.
if ($added_comment_fileline) {
    $stmt = $dbh->prepare_cached('SELECT DISTINCT topicid, line FROM comment');
    $stmt->execute();
    while (my ($topicid, $line) = $stmt->fetchrow_array()) {
	my ($filenumber, $fileline, $filename, $accurate);
	Codestriker::Action::SubmitComment->
	    _get_file_linenumber($topicid, $line, \$filenumber, \$filename,
				 \$fileline, \$accurate);

	# Check if this topic doesn't have a filetable defined.
	if ($filenumber == -1) {
	    $fileline = 0;
	    $filename = "unknown";
	}
	
	print "Updating comment and commentstate row for topicid $topicid\n";
	print " filenumber $filenumber fileline $fileline\n";
	my $update = $dbh->prepare_cached('UPDATE commentstate SET ' .
					  'filenumber = ?, filename = ? AND ' .
					  'fileline = ? ' .
					  'WHERE topicid = ? AND line = ?');
	$update->execute($filenumber, $filename, $fileline, $topicid, $line);
	$update->finish();

	$update = $dbh->prepare_cached('UPDATE comment SET ' .
				       'filenumber = ? and fileline = ? ' .
				       'WHERE topicid = ? AND line = ?');
	$update->execute($filenumber, $fileline, $topicid, $line);
	$update->finish();
    }
    $stmt->finish();
}

# Create the appropriate file and delta rows for each topic, if they don't
# already exist.
$stmt = $dbh->prepare_cached('SELECT id FROM topic');
$stmt->execute();
while (my ($topicid) = $stmt->fetchrow_array()) {
    # Check if there is an associated delta record, and if not create it.
    my $check = $dbh->prepare_cached('SELECT COUNT(*) FROM delta ' .
				     'WHERE topicid = ?');
    $check->execute($topicid);
    my ($count) = $check->fetchrow_array();
    $check->finish();
    next if ($count != 0);

    print "Creating delta rows for topic $topicid\n";

    # This topic doesn't have associated delta records.  Create them
    # now.  Note, it may have associated file records, these should be
    # removed and replaced, but first the associated repository URL
    # should be read.
    my $rep_stmt = $dbh->prepare_cached('SELECT repository, document '.
					'FROM topic WHERE id = ?');
    $rep_stmt->execute($topicid);
    my ($repository_url, $document) = $rep_stmt->fetchrow_array();
    $rep_stmt->finish();

    # Determine the appropriate repository object (if any) for this topic.
    my $repository = undef;
    if (defined $repository_url && $repository_url ne "") {
	$repository =
	    Codestriker::Repository::RepositoryFactory->get($repository);
    }

    # Load the default repository if nothing has been set.
    if (! defined($repository)) {
	$repository_url = $Codestriker::valid_repositories[0];
	$repository =
	    Codestriker::Repository::RepositoryFactory->get($repository_url);
    }

    # Determine the repository root.
    my $repository_root = "";
    if (defined $repository) {
	$repository_root = $repository->getRoot();
    }

    # Create a temporary file containing the document, so that the
    # standard parsing routines can be used.
    my $tmpfile = "tmptopic.txt";
    open(TEMP_FILE, ">$tmpfile") ||
	die "Failed to create temporary topic file \"$tmpfile\": $!";
    print TEMP_FILE $document;
    close TEMP_FILE;
    open(TEMP_FILE, "$tmpfile") ||
	die "Failed to open temporary file \"$tmpfile\": $!";

    # Parse the document, and extract the diffs out of it.
    my @deltas =
	Codestriker::FileParser::Parser->parse(\*TEMP_FILE, "text/plain",
					       $repository_root);
    close TEMP_FILE;
    unlink($tmpfile);

    my $deletefile_stmt =
	$dbh->prepare_cached('DELETE FROM file WHERE topicid = ?');
    $deletefile_stmt->execute($topicid);
    Codestriker::Model::File->create($dbh, $topicid, \@deltas,
				     $repository);
}
$stmt->finish();

# If the commentstate.filenumber column was added, since the primary key
# of this table has changed, move the current table to a temporary table,
# create the new commentstate table, and migrate the data across.  Note,
# nested queries can't be used for MySQL.
if ($added_commentstate_filenumber) {
    
    print "Creating new commentstate table and migrating data...\n";
    $dbh->do('RENAME TABLE commentstate TO commentstatebak') ||
	die "Could not rename table commentstate: " . $dbh->errstr;

    my $fields = $table{commentstate};
    $dbh->do("CREATE TABLE commentstate (\n$fields\n)") ||
	die "Could not create table commentstate: " . $dbh->errstr;

    if (defined $index{commentstate}) {
	$dbh->do($index{commentstate}) ||
	    die "Could not create indexes for table commentstate: " .
	    $dbh->errstr;
    }

    # Now read the data from the old table, and populate the new table.
    my $select =
	$dbh->prepare_cached('SELECT topicid, line, state, filename, ' .
			     'fileline, filenumber, version ' .
			     'FROM commentstatebak');
    $select->execute();
    while (my ($topicid, $line, $state, $filename, $fileline, $filenumber,
	       $version) = $select->fetchrow_array()) {
	print "Handling topic $topicid\n";
	my $insert =
	    $dbh->prepare_cached('INSERT INTO commentstate ' .
				 '(topicid, line, state, filename, ' .
				 'fileline, filenumber, version) ' .
				 'VALUES (?, ?, ?, ?, ?, ?, ?)');
	$insert->execute($topicid, $line, $state, $filename, $fileline,
			 $filenumber, $version);
	$insert->finish();
    }
    $select->finish();

    # Finally, drop the old commentstateback table.
    $dbh->do('DROP TABLE commentstatebak') ||
	die "Could not drop table commentstatebak: " . $dbh->errstr;
    print "Done\n";
}    

# Insert the version number into the table, if required.
$stmt = $dbh->prepare_cached('SELECT id, sequence FROM version');
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

Codestriker::DB::DBI->release_connection($dbh, 1);

