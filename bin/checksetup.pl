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
use File::Path;
use Codestriker::DB::DBI;
use Codestriker::Action::SubmitComment;
use Codestriker::Repository::RepositoryFactory;
use Codestriker::FileParser::Parser;
use Codestriker::FileParser::UnknownFormat;

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

# The commentstate table needs a unique id.  For MySQL, use an auto
# incrementor.  For PostgreSQL and other databases, use a sequence.
my $auto_increment = ($Codestriker::db =~ /^DBI:mysql/i) ?
    "auto_increment" : "default nextval('sequence')";

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
     projectid int NOT NULL,
     PRIMARY KEY (id)";

$index{topic} = "CREATE INDEX author_idx ON topic(author)";

$table{comment} =
    "commentstateid int NOT NULL,
     commentfield text NOT NULL,
     author varchar(255) NOT NULL,
     creation_ts timestamp NOT NULL";

$table{commentstate} =
    "id int NOT NULL $auto_increment,
     topicid int NOT NULL,
     fileline int NOT NULL,
     filenumber int NOT NULL,
     filenew smallint NOT NULL,
     state smallint NOT NULL,
     version int NOT NULL,
     creation_ts timestamp NOT NULL,
     modified_ts timestamp NOT NULL,
     PRIMARY KEY (id)";

$index{commentstate} =
    "CREATE INDEX commentstate_topicid_idx ON commentstate(topicid)";

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
     repmatch smallint NOT NULL,
     PRIMARY KEY (topicid, delta_sequence)";

$index{delta} = "CREATE INDEX delta_fid_idx ON delta(topicid)";

$table{project} =
    "id int NOT NULL $auto_increment,
     name varchar(255) NOT NULL,
     description $text_type NOT NULL,
     creation_ts timestamp NOT NULL,
     modified_ts timestamp NOT NULL,
     version int NOT NULL,
     PRIMARY KEY (id)";

$index{project} = "CREATE UNIQUE INDEX project_name_idx ON project(name)";

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

# Move a table into table_old, create the table with the new definitions,
# and create the indexes.
sub move_old_table ($$)
{
    my ($tablename, $pkey_column) = @_;
    
    $dbh->do("ALTER TABLE $tablename RENAME TO ${tablename}_old") ||
	die "Could not rename table $tablename: " . $dbh->errstr;


    # For PostgreSQL, need to drop and create the old primary key index
    # with a different name, otherwise the create table command below
    # will fail.
    if (defined $pkey_column && $Codestriker::db =~ /^DBI:pg/i) {
	$dbh->do("DROP INDEX ${tablename}_pkey") ||
	    die "Could not drop pkey index: " . $dbh->errstr;
	$dbh->do("CREATE UNIQUE INDEX ${tablename}_old_pkey ON " .
		 "${tablename}_old($pkey_column)") ||
		 die "Could not create pkey index for old table: " .
		 $dbh->errstr;
    }
    
    my $fields = $table{$tablename};
    $dbh->do("CREATE TABLE $tablename (\n$fields\n)") ||
	die "Could not create table $tablename: " . $dbh->errstr;
    
    if (defined $index{$tablename}) {
	$dbh->do($index{$tablename}) ||
	    die "Could not create indexes for table $tablename: " .
	    $dbh->errstr;
    
    }
}

# Check if the specified column exists in the specified table.
sub column_exists ($$)
{
    my ($tablename, $columnname) = @_;

    my $local_dbh = Codestriker::DB::DBI->get_connection();
    $local_dbh->{RaiseError} = 0;
    $local_dbh->{PrintError} = 0;

    my $stmt =
	$local_dbh->prepare_cached("SELECT COUNT($columnname) " .
				   "FROM $tablename");

    my $rc = defined $stmt && $stmt->execute() ? 1 : 0;

    if (defined $stmt) {
	$stmt->finish();
    }

    Codestriker::DB::DBI->release_connection($local_dbh, 1);

    return $rc;
}

# Create a new commentstate record with the specified data values.  Return
# the id of the commentstate record created.
sub create_commentstate ($$$$)
{
    my ($topicid, $line, $state, $version) = @_;

    print " Updating commentstate topicid $topicid offset $line\n";

    # Determine what filenumber, fileline and filenew the old "offset"
    # number refers to.  If it points to an actual diff/block, just
    # return 
    my ($filenumber, $filename, $fileline, $filenew, $accurate);
    my $rc = Codestriker::Action::SubmitComment->
	_get_file_linenumber($topicid, $line, \$filenumber, \$filename,
			     \$fileline, \$accurate, \$filenew);
    if ($rc == 0) {
	# Review is not a diff, just a single file.
	$filenumber = 1;
	$fileline = $line;
	$filenew = 1;
    } elsif ($filenumber == -1) {
	# Comment was made against a diff header.
	$filenumber = 1;
	$fileline = 1;
	$filenew = 1;
    }
	    
    my $insert = $dbh->prepare_cached(
		"INSERT INTO commentstate (topicid, fileline, filenumber, " .
		"filenew, state, version, creation_ts, modified_ts) VALUES " .
	        "(?, ?, ?, ?, ?, ?, ?, ?)");
    my $timestamp = Codestriker->get_timestamp(time);
    $insert->execute($topicid, $fileline, $filenumber, $filenew,
		     $state, $version, $timestamp, $timestamp);
    $insert->finish();
    print "Create commentstate\n";
    
    # Find out what the commentstateid is, and update the
    # topicoffset_map.
    my $check = $dbh->prepare_cached("SELECT id FROM commentstate " .
				     "WHERE topicid = ? AND " .
				     "fileline = ? AND " .
				     "filenumber = ? AND " .
				     "filenew = ?");
    $check->execute($topicid, $fileline, $filenumber, $filenew);
    my ($id) = $check->fetchrow_array();
    $check->finish();

    return $id;
}
    
# If we aren't using MySQL, create the sequence if required.
if ($Codestriker::db !~ /^DBI:mysql/i) {
    # Perform this operation in a separate connection, so any errors won't
    # affect the outer transaction.
    my $local_dbh = Codestriker::DB::DBI->get_connection();
    $local_dbh->{RaiseError} = 0;
    $local_dbh->{PrintError} = 0;
    if (! $local_dbh->do("CREATE SEQUENCE sequence")) {
	# Most likely, the sequence already exists, silently continue.
    } else {
	print "Created sequence\n";
    }
    Codestriker::DB::DBI->release_connection($local_dbh, 1);
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
add_field('topic', 'projectid', 'int');

# Determine if the comment and/or commentstate tables are old.
my $old_comment_table = column_exists("comment", "line");
my $old_commentstate_table = column_exists("commentstate", "line");

if ($old_comment_table) {
    my %topicoffset_map;
    print "Detected old version of comment table, migrating...\n";

    # Need to migrate the data to the new style of the table data.
    move_old_table("comment", undef);
    move_old_table("commentstate", "topicid, line") if $old_commentstate_table;

    my $stmt;
    if ($old_commentstate_table) {
	print "Detected old version of commentstate table, migrating...\n";
	# Update the commentstate table.
	$stmt =
	    $dbh->prepare_cached("SELECT topicid, state, line, version " .
				 "FROM commentstate_old");
	$stmt->execute();
	while (my ($topicid, $state, $line, $version) =
	       $stmt->fetchrow_array()) {
	    $topicoffset_map{"$topicid|$line"} =
		create_commentstate($topicid, $line, $state, $version);
	}
	$stmt->finish();
	$dbh->do('DROP TABLE commentstate_old');
    } else {
	# Version of codestriker which didn't have a commentstate table.
	# Need to create new commentstate rows for each distinct comment
	# first, then update each individual comment row appropriately.
	move_old_table("comment", undef);
	
	$stmt = $dbh->prepare_cached('SELECT DISTINCT topicid, line ' .
					'FROM comment_old');
	$stmt->execute();
	while (my ($topicid, $line) = $stmt->fetchrow_array()) {
	    print " Migrating comment for topic $topicid offset $line...\n";

	    # Create a commentstate row for this comment.
	    my $id = create_commentstate($topicid, $line,
					 $Codestriker::COMMENT_SUBMITTED, 0);
	    $topicoffset_map{"$topicid|$line"} = $id;
	}
	$stmt->finish();
    }
    
    # Now update each comment row to refer to the appropriate commentstate
    # row.
    $stmt = $dbh->prepare_cached('SELECT topicid, commentfield, author, ' .
				 'line, creation_ts FROM comment_old');
    $stmt->execute();
    while (my ($topicid, $commentfield, $author, $line, $creation_ts) =
	   $stmt->fetchrow_array()) {
	
	# Update the associated row in the new comment table.
	my $insert = $dbh->prepare_cached('INSERT INTO comment ' .
					  '(commentstateid, commentfield, ' .
					  'author, creation_ts) VALUES ' .
					  '(?, ?, ?, ?)');
	print " Updating comment topicid $topicid offset $line...\n";
	$insert->execute($topicoffset_map{"$topicid|$line"},
			 $commentfield, $author, $creation_ts);
	$insert->finish();
    }
    $stmt->finish();

    # Drop the old comment table.
    $dbh->do('DROP TABLE comment_old');
    print "Done\n";
}
	
# Create the appropriate file and delta rows for each topic, if they don't
# already exist.
my $stmt = $dbh->prepare_cached('SELECT id FROM topic');
$stmt->execute();
while (my ($topicid) = $stmt->fetchrow_array()) {
    # Check if there is an associated delta record, and if not create it.
    my $check = $dbh->prepare_cached('SELECT COUNT(*) FROM delta ' .
				     'WHERE topicid = ?');
    $check->execute($topicid);
    my ($count) = $check->fetchrow_array();
    $check->finish();
    next if ($count != 0);

    # Check if there is a file record for this topic.  If not, just create
    # a simple 1 file, 1 delta record, so that the old comment offsets are
    # preserved.
    $check = $dbh->prepare_cached('SELECT COUNT(*) FROM file ' .
				  'WHERE topicid = ?');
    $check->execute($topicid);
    my ($filecount) = $check->fetchrow_array();
    $check->finish();
    
    # Determine what repository and document is associated with this topic.
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
    
    # Create a temporary file containing the document, so that the
    # standard parsing routines can be used.
    my $tmpfile = "tmptopic.txt";
    open(TEMP_FILE, ">$tmpfile") ||
	die "Failed to create temporary topic file \"$tmpfile\": $!";
    print TEMP_FILE $document;
    close TEMP_FILE;
    open(TEMP_FILE, "$tmpfile") ||
	die "Failed to open temporary file \"$tmpfile\": $!";

    my @deltas = ();
    if ($filecount == 0) {
	# Parse the document as a single file, for backward compatibility,
	# so that the comment offsets are preserved.
	print "Creating 1 delta object for topic $topicid\n";
	@deltas =
	    Codestriker::FileParser::UnknownFormat->parse(\*TEMP_FILE);

    } else {
	# Parse the document, and extract the diffs out of it.
	@deltas =
	    Codestriker::FileParser::Parser->parse(\*TEMP_FILE, "text/plain",
						   $repository, $topicid);
	print "Creating $#deltas deltas for topic $topicid\n";
	my $deletefile_stmt =
	    $dbh->prepare_cached('DELETE FROM file WHERE topicid = ?');
	$deletefile_stmt->execute($topicid);
    }

    print "Creating delta rows for topic $topicid\n";
    Codestriker::Model::File->create($dbh, $topicid, \@deltas,
				     $repository);

    # Delete the temporary file.
    close TEMP_FILE;
    unlink($tmpfile);
}
$stmt->finish();

# Check if the version to be upgraded has any project rows or not, and if
# not, link all topics to the default project.
$stmt = $dbh->prepare_cached('SELECT COUNT(*) FROM project');
$stmt->execute();
my ($project_count) = $stmt->fetchrow_array();
$stmt->finish();
if ($project_count == 0) {
    # Create a default project entry, which can then be modified by the user
    # later.
    print "Creating default project...\n";
    my $timestamp = Codestriker->get_timestamp(time);
    my $create = $dbh->prepare_cached('INSERT INTO project ' .
				      '(name, description, creation_ts, ' .
				      'modified_ts, version ) ' .
				      'VALUES (?, ?, ?, ?, ?) ');
    $create->execute('Default project', 'Default project description',
		     $timestamp, $timestamp, 0);
    $create->finish();

    # Get the id of this project entry.
    my $select = $dbh->prepare_cached('SELECT MIN(id) FROM project');
    $select->execute();
    my ($projectid) = $select->fetchrow_array();
    $select->finish();

    # Now link all the topics in the system with this default project.
    print "Linking all topics to default project...\n";
    my $update = $dbh->prepare_cached('UPDATE topic SET projectid = ?');
    $update->execute($projectid);
    $update->finish();
}

# Clean out the contents of the data and template directory, but don't
# remove them.
chdir('../cgi-bin') ||
    die "Couldn't change to cgi-dir directory: $!";
if (-d 'template/en') {
    print "Cleaning old template directory...\n";
    rmtree(['template/en'], 0, 1);
}

print "Done\n";

Codestriker::DB::DBI->release_connection($dbh, 1);

