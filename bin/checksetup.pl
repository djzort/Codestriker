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
use Config;

# Now load up the required modules.  Do this is a lazy fashion so that Perl
# doesn't try to grab this during compile time, otherwise nasty-looking
# error messages will appear to the user.
eval("use Cwd");
eval("use File::Path");
eval("use lib '../lib'");
eval("use Codestriker");
eval("use Codestriker::DB::Database");
eval("use Codestriker::DB::Column");
eval("use Codestriker::DB::Table");
eval("use Codestriker::DB::Index");
eval("use Codestriker::Action::SubmitComment");
eval("use Codestriker::Repository::RepositoryFactory");
eval("use Codestriker::FileParser::Parser");
eval("use Codestriker::FileParser::UnknownFormat");

# Set this variables, to avoid compilation warnings below.
$Codestriker::COMMENT_SUBMITTED = 0;
@Codestriker::valid_repositories = ();

# Initialise Codestriker, load up the configuration file.
Codestriker->initialise(cwd() . '/..');

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
    },
    { 
        name => 'HTML::Entities', 
        version => '0' 
    },
    { 
        name => 'File::Temp', 
        version => '0' 
    } 
];

# Retrieve the database module dependencies.  Put this in an eval block to
# handle the case where the user hasn't installed the DBI module yet,
# which prevents the following code from running.
my $database = undef;
eval {
    $database = Codestriker::DB::Database->get_database();
    push @{$modules}, $database->get_module_dependencies();
};

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
    # Determine if this process is running under Windows, as the installation
    # process is different.
    my $osname = $Config{'osname'};
    my $windows = (defined $osname && $osname eq "MSWin32") ? 1 : 0;

    # First, output the generic "missing module" message.
    print "\n\n";
    print "Codestriker requires some Perl modules which are either missing\n" .
	  "from your system, or the version on your system is too old.\n";

    if ($windows) {
	foreach my $module (keys %missing) {
	    print " Missing \"$module\"\n";
	    if ($missing{$module} > 0) {
		print "   Minimum version required: $missing{$module}\n";
	    }
	}

	print <<EOF;

These can be installed by doing the following in PPM 2.0 (the version of ppm is
displayed when you start it up).

C:\> ppm

PPM> set repository oi http://openinteract.sourceforge.net/ppmpackages
PPM> set save
PPM> install (package-name)

For PPM 3.0:

C:\> ppm
PPM> rep add oi http://openinteract.sourceforge.net/ppmpackages
PPM> install (package-name)

*NOTE* The Template package name may not be "Template" but "Template-Toolkit"
when entering the commands above.

http://openinteract.sourceforge.net/cgi-bin/twiki/view/OI/ActivePerlPackages
has more information if you still have problems.

Another repository of Perl packages is http://theoryx5.uwinnipeg.ca/ppmpackages
which also has mod_perl for Win32.

The ActiveState default repository in PPM has almost all of the packages
required.
EOF
    }
    else {
	print "They can be installed by running (as root) the following:\n";
	foreach my $module (keys %missing) {
	    print "   perl -MCPAN -e 'install \"$module\"'\n";
	    if ($missing{$module} > 0) {
		print "   Minimum version required: $missing{$module}\n";
	    }
	}
	print "\n";
	print "Modules can also be downloaded from http://www.cpan.org.\n\n";
    }
    exit;
}

# Obtain a database connection.
my $dbh = $database->get_connection();

# Convenience methods and variables for creating table objects.
my $TEXT = $Codestriker::DB::Column::TYPE->{TEXT};
my $VARCHAR = $Codestriker::DB::Column::TYPE->{VARCHAR};
my $INT32 = $Codestriker::DB::Column::TYPE->{INT32};
my $INT16 = $Codestriker::DB::Column::TYPE->{INT16};
my $DATETIME = $Codestriker::DB::Column::TYPE->{DATETIME};
my $FLOAT = $Codestriker::DB::Column::TYPE->{FLOAT};
sub col { return Codestriker::DB::Column->new(@_); }
sub dbindex { return Codestriker::DB::Index->new(@_); }
sub table { return Codestriker::DB::Table->new(@_); }

# The topic table.
my $topic_table =
  table(name => "topic",
	columns => [col(name=>"id", type=>$INT32, pk=>1),
		    col(name=>"author", type=>$VARCHAR, length=>255),
		    col(name=>"title", type=>$VARCHAR, length=>255),
		    col(name=>"description", type=>$TEXT),
		    col(name=>"document", type=>$TEXT),
		    col(name=>"state", type=>$INT16),
		    col(name=>"creation_ts", type=>$DATETIME),
		    col(name=>"modified_ts", type=>$DATETIME),
		    col(name=>"version", type=>$INT32),
		    col(name=>"start_tag", type=>$TEXT, mandatory=>0),
		    col(name=>"end_tag", type=>$TEXT, mandatory=>0),
		    col(name=>"module", type=>$TEXT, mandatory=>0),
		    col(name=>"repository", type=>$TEXT, mandatory=>0),
		    col(name=>"projectid", type=>$INT32)
		   ],
	indexes => [dbindex(name=>"author_idx", column_names=>["author"])]);

# The topichistory table.  Holds information relating to how a topic
# has changed over time.  Only changeable topic attributes are
# recorded in this table.
my $topichistory_table =
  table(name => "topichistory",
	columns => [col(name=>"topicid", type=>$INT32, pk=>1),
		    col(name=>"author", type=>$VARCHAR, length=>255),
		    col(name=>"title", type=>$VARCHAR, length=>255),
		    col(name=>"description", type=>$TEXT, length=>255),
		    col(name=>"state", type=>$INT16),
		    col(name=>"modified_ts", type=>$DATETIME),
		    col(name=>"version", type=>$INT32, pk=>1),
		    col(name=>"repository", type=>$TEXT, mandatory=>0),
		    col(name=>"projectid", type=>$INT32),
		    col(name=>"reviewers", type=>$TEXT),
		    col(name=>"cc", type=>$TEXT, mandatory=>0),
		    col(name=>"modified_by_user", type=>$VARCHAR, length=>255, mandatory=>0)
		   ],
	indexes => [dbindex(name=>"th_idx", column_names=>["topicid"])]);
	
# Holds information as to when a user viewed a topic.
my $topicviewhistory_table =
  table(name => "topicviewhistory",
	columns => [col(name=>"topicid", type=>$INT32),
		    col(name=>"email", type=>$VARCHAR, length=>255, mandatory=>0),
		    col(name=>"creation_ts", type=>$DATETIME)
		   ],
	indexes => [dbindex(name=>"tvh_idx", column_names=>["topicid"])]);

# Holds all of the metric data that is owned by a specific user on a specific 
# topic. One row per metric. Metric data that is left empty does not get a row.
my $topicusermetric_table =
  table(name => "topicusermetric",
	columns => [col(name=>"topicid", type=>$INT32, pk=>1),
		    col(name=>"email", type=>$VARCHAR, length=>255, pk=>1),
		    col(name=>"metric_name", type=>$VARCHAR, length=>80, pk=>1),
		    col(name=>"value", type=>$FLOAT)
		   ],
	indexes => [dbindex(name=>"tum_idx",
			    column_names=>["topicid", "email"])]);

# Holds all of the metric data that is owned by a specific topic. One row per 
# metric. Metric data that is empty does not get a row.
my $topicmetric_table =
  table(name => "topicmetric",
	columns => [col(name=>"topicid", type=>$INT32, pk=>1),
		    col(name=>"metric_name", type=>$VARCHAR, length=>80,pk=>1),
		    col(name=>"value", type=>$FLOAT)
		   ],
	indexes => [dbindex(name=>"tm_idx", column_names=>["topicid"])]);

# Hold a specific datum of column data entered by a specific user for a
# specific line.
my $commentdata_table =
  table(name => "commentdata",
	columns => [col(name=>"commentstateid", type=>$INT32),
		    col(name=>"commentfield", type=>$TEXT),
		    col(name=>"author", type=>$VARCHAR, length=>255),
		    col(name=>"creation_ts", type=>$DATETIME)
		   ],
	indexes => [dbindex(name=>"comment_idx",
			    column_names=>["commentstateid"])]);

# Contains the state of a bunch of comments on a specific line of code.
my $commentstate_table =
  table(name => "commentstate",
	columns => [col(name=>"id", type=>$INT32, autoincr=>1, pk=>1),
		    col(name=>"topicid", type=>$INT32),
		    col(name=>"fileline", type=>$INT32),
		    col(name=>"filenumber", type=>$INT32),
		    col(name=>"filenew", type=>$INT16),
		    col(name=>"state", type=>$INT16),  # Not used, old field.
		    col(name=>"version", type=>$INT32),
		    col(name=>"creation_ts", type=>$DATETIME),
		    col(name=>"modified_ts", type=>$DATETIME)
		   ],
	indexes => [dbindex(name=>"commentstate_topicid_idx",
			    column_names=>["topicid"])]);

# Contains the metrics associated with a commentstate record.  This is
# configurable over time, so basic string data is stored into here.
my $commentstatemetric_table =
  table(name => "commentstatemetric",
	columns => [col(name=>"id", type=>$INT32, pk=>1),
		    col(name=>"name", type=>$VARCHAR, length=>80, pk=>1),
		    col(name=>"value", type=>$VARCHAR, length=>80)
		    ],
	indexes => [dbindex(name=>"csm_id_idx", column_names=>["id"]),
		    dbindex(name=>"csm_name_idx", column_names=>["name"])]);
		    
# Holds information relating to how a commentstate has changed over time.
# Only changeable commentstate attributes are recorded in this table.
my $commentstatehistory_table =
  table(name => "commentstatehistory",
	columns => [col(name=>"id", type=>$INT32, pk=>1),
                    col(name=>"state", type=>$INT16),  # Not used, old field.
		    col(name=>"metric_name", type=>$VARCHAR, length=>80),
		    col(name=>"metric_value", type=>$VARCHAR, length=>80),
		    col(name=>"version", type=>$INT32, pk=>1),
		    col(name=>"modified_ts", type=>$DATETIME),
		    col(name=>"modified_by_user", type=>$VARCHAR, length=>255)
		    ]);

# Indicate what participants there are in a topic.
my $participant_table =
  table(name => "participant",
	columns => [col(name=>"topicid", type=>$INT32, pk=>1),
		    col(name=>"email", type=>$VARCHAR, length=>255, pk=>1),
		    col(name=>"type", type=>$INT16, pk=>1),
		    col(name=>"state", type=>$INT16),
		    col(name=>"modified_ts", type=>$DATETIME),
		    col(name=>"version", type=>$INT32)
		   ],
	indexes => [dbindex(name=>"participant_tid_idx",
			    column_names=>["topicid"])]);

# Indicate how bug records are related to topics.
my $topicbug_table =
  table(name => "topicbug",
	columns => [col(name=>"topicid", type=>$INT32, pk=>1),
		    col(name=>"bugid", type=>$INT32, pk=>1)
		   ],
	indexes => [dbindex(name=>"topicbug_tid_idx",
			    column_names=>["topicid"])]);

# This table records which file fragments are associated with a topic.
my $topicfile_table =
  table(name => "topicfile",
	columns => [col(name=>"topicid", type=>$INT32, pk=>1),
		    col(name=>"sequence", type=>$INT16, pk=>1),
		    col(name=>"filename", type=>$VARCHAR, length=>255),
		    col(name=>"topicoffset", type=>$INT32),
		    col(name=>"revision", type=>$VARCHAR, length=>255),
		    col(name=>"binaryfile", type=>$INT16),
		    col(name=>"diff", type=>$TEXT, mandatory=>0)
		   ],
	indexes => [dbindex(name=>"topicfile_tid_idx",
			    column_names=>["topicid"])]);

# This table records a specific "delta", which is a chunk of a diff file.
my $delta_table =
  table(name => "delta",
	columns => [col(name=>"topicid", type=>$INT32, pk=>1),
		    col(name=>"file_sequence", type=>$INT16),
		    col(name=>"delta_sequence", type=>$INT16, pk=>1),
		    col(name=>"old_linenumber", type=>$INT32),
		    col(name=>"new_linenumber", type=>$INT32),
		    col(name=>"deltatext", type=>$TEXT),
		    col(name=>"description", type=>$TEXT, mandatory=>0),
		    col(name=>"repmatch", type=>$INT16)
		   ],
	indexes => [dbindex(name=>"delta_fid_idx",
			    column_names=>["topicid"])]);

# This table records all projects in the system.
my $project_table =
  table(name => "project",
	columns => [col(name=>"id", type=>$INT32, pk=>1, autoincr=>1),
		    col(name=>"name", type=>$VARCHAR, length=>255),
		    col(name=>"description", type=>$TEXT),
		    col(name=>"creation_ts", type=>$DATETIME),
		    col(name=>"modified_ts", type=>$DATETIME),
		    col(name=>"version", type=>$INT32),
		    col(name=>"state", type=>$INT16)
		   ],
	indexes => [dbindex(name=>"project_name_idx",
			    column_names=>["name"])]);

# Add all of the Codestriker tables into an array.
my @tables = ();
push @tables, $topic_table;
push @tables, $topichistory_table;
push @tables, $topicviewhistory_table;
push @tables, $topicusermetric_table;
push @tables, $topicmetric_table;
push @tables, $commentdata_table;
push @tables, $commentstate_table;
push @tables, $commentstatemetric_table;
push @tables, $commentstatehistory_table;
push @tables, $participant_table;
push @tables, $topicbug_table;
push @tables, $topicfile_table;
push @tables, $delta_table;
push @tables, $project_table;

# Move a table into table_old, create the table with the new definitions,
# and create the indexes.
sub move_old_table ($$)
{
    my ($table, $pkey_column) = @_;
    my $tablename = $table->get_name();

    # Rename the table with this name to another name.
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

    # Now create the table.
    $database->create_table($table);
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
    
# Migrate the "file" table to "topicfile", to avoid keyword issues with ODBC
# and Oracle.  Make sure the error values of the database connection are
# correctly set, to handle the most likely case where the "file" table doesn't
# even exist.  
$database->move_table("file", "topicfile");

# Migrate the "comment" table to "commentdata", to avoid keyword issues with
# ODBC and Oracle.  Make sure the error values of the database connection are
# correctly set, to handle the most likely case where the "file" table doesn't
# even exist.
$database->move_table("comment", "commentdata");

# Retrieve the tables which currently exist in the database, to determine
# which databases are missing.
my @existing_tables = $database->get_tables();

foreach my $table (@tables) {
    my $table_name = $table->get_name();
    next if grep /^${table_name}$/i, @existing_tables;

    print "Creating table " . $table->get_name() . "...\n";
    $database->create_table($table);
}

# Make sure the database is committed before proceeding.
$database->commit();

# Add new fields to the topic field when upgrading old databases.
$database->add_field('topic', 'repository', $TEXT);
$database->add_field('topic', 'projectid', $INT32);
$database->add_field('topic', 'start_tag', $TEXT);
$database->add_field('topic', 'end_tag', $TEXT);
$database->add_field('topic', 'module', $TEXT);

# Add the new metric fields to the commentstatehistory table.
$database->add_field('commentstatehistory', 'metric_name', $TEXT);
$database->add_field('commentstatehistory', 'metric_value', $TEXT);

# Add the new state field to the project table
$database->add_field('project', 'state', $INT16);

# If we are using MySQL, and we are upgrading from a version of the database
# which used "text" instead of "mediumtext" for certain fields, update the
# appropriate table columns.
if ($Codestriker::db =~ /^DBI:mysql/i) {
    # Check that document field in topic is up-to-date.
    my $ref = $database->get_field_def("topic", "document");
    my $text_type = $database->_map_type($TEXT);
    if ($$ref[1] ne $text_type) {
	print "Updating topic table for document field to be $text_type...\n";
	$dbh->do("ALTER TABLE topic CHANGE document document $text_type") ||
	    die "Could not alter topic table: " . $dbh->errstr;
    }
}

# Determine if the commentdata and/or commentstate tables are old.
my $old_comment_table = $database->column_exists("commentdata", "line");
my $old_commentstate_table = $database->column_exists("commentstate", "line");

if ($old_comment_table) {
    my %topicoffset_map;
    print "Detected old version of commentdata table, migrating...\n";

    # Need to migrate the data to the new style of the table data.
    move_old_table("commentdata", undef);
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
	move_old_table("commentdata", undef);
	
	$stmt = $dbh->prepare_cached('SELECT DISTINCT topicid, line ' .
				     'FROM commentdata_old');
	$stmt->execute();
	while (my ($topicid, $line) = $stmt->fetchrow_array()) {
	    print " Migrating comment for topic $topicid offset $line...\n";

	    # Create a commentstate row for this comment.
	    my $id = create_commentstate($topicid, $line,
					 $Codestriker::COMMENT_SUBMITTED,
					 0);
	    $topicoffset_map{"$topicid|$line"} = $id;
	}
	$stmt->finish();
    }
    
    # Now update each comment row to refer to the appropriate commentstate
    # row.
    $stmt = $dbh->prepare_cached('SELECT topicid, commentfield, author, ' .
				 'line, creation_ts FROM commentdata_old');
    $stmt->execute();
    while (my ($topicid, $commentfield, $author, $line, $creation_ts) =
	   $stmt->fetchrow_array()) {
	
	# Update the associated row in the new comment table.
	my $insert = $dbh->prepare_cached('INSERT INTO commentdata ' .
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
    $dbh->do('DROP TABLE commentdata_old');

    # Commit these changes.
    $database->commit();
    print "Done\n";
}
	
# Create the appropriate file and delta rows for each topic, if they don't
# already exist.  Apparently SQL Server doesn't allow multiple statements
# to be active at any given time (gack!) so store the topic list into an
# array first.  The things we do... what a bloody pain and potential
# memory hog.
my $stmt = $dbh->prepare_cached('SELECT id FROM topic');
$stmt->execute();
my @topic_list = ();
while (my ($topicid) = $stmt->fetchrow_array()) {
    push @topic_list, $topicid;
}
$stmt->finish();

foreach my $topicid (@topic_list) {
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
    $check = $dbh->prepare_cached('SELECT COUNT(*) FROM topicfile ' .
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
	    $dbh->prepare_cached('DELETE FROM topicfile WHERE topicid = ?');
	$deletefile_stmt->execute($topicid);
    }

    print "Creating delta rows for topic $topicid\n";
    Codestriker::Model::File->create($dbh, $topicid, \@deltas,
				     $repository);

    # Delete the temporary file.
    close TEMP_FILE;
    unlink($tmpfile);
}
$database->commit();

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

    # Get the id of this project entry.
    my $select = $dbh->prepare_cached('SELECT MIN(id) FROM project');
    $select->execute();
    my ($projectid) = $select->fetchrow_array();
    $select->finish();

    # Now link all the topics in the system with this default project.
    print "Linking all topics to default project...\n";
    my $update = $dbh->prepare_cached('UPDATE topic SET projectid = ?');
    $update->execute($projectid);
}
$database->commit();

# Check if the version to be upgraded has any project rows and if
# so set the default state to open.
$stmt = $dbh->prepare_cached('UPDATE project SET state = 0 WHERE state IS NULL');
$stmt->execute();
$database->commit();

# Check if the data needs to be upgraded to the new commentstate metric
# scheme from the old state_id scheme.  For now, assume the old state-ids
# are the default values present in Codestriker.conf.  If they were changed
# by the user, they could always modify the DB values appropriately.
eval {
    $dbh->{PrintError} = 0;

    # This array should reflect the value of @comment_states in your old
    # codestriker.conf file, and is used for data migration purposes.
    # This value represents the default value used in Codestriker.
    my @old_comment_states = ("Submitted", "Invalid", "Completed");

    $stmt = $dbh->prepare_cached('SELECT id, state, creation_ts, modified_ts '.
				 'FROM commentstate WHERE state >= 0');
    $stmt->execute();
    
    my $update = $dbh->prepare_cached('UPDATE commentstate ' .
				      'SET state = ?, creation_ts = ?, ' .
				      'modified_ts = ? ' .
				      'WHERE id = ?');
    my $insert = $dbh->prepare_cached('INSERT INTO commentstatemetric ' .
				      '(id, name, value) VALUES (?, ?, ?) ');
    
    my $count = 0;
    my @update_rows = ();
    while (my ($id, $state, $creation_ts, $modified_ts) =
	   $stmt->fetchrow_array()) {
	if ($count == 0) {
	    print "Migrating old commentstate records... \n";
	    print "Have you updated the \@old_comment_states variable on line 767? (y/n): ";
	    flush STDOUT;
	    my $answer = <STDIN>;
	    chop $answer;
	    if (! ($answer =~ /^y/i)) {
		print "Aborting script... update \@old_comment_states in this script and run again.\n";
		$stmt->finish();
		exit(1);
	    }
	}

	# We can't update this now due to ^%@$# SQL server, we do that below.
	my $value = $old_comment_states[$state];
	$value = "Unknown $state" unless defined $value;
	push @update_rows, { state => -$state - 1,
			     creation_ts => $creation_ts,
			     modified_ts => $modified_ts,
			     id => $id,
			     value => $value };
	$count++;
    }
    $stmt->finish();

    foreach my $row (@update_rows) {
	# Update the state to its negative value, so the information isn't
	# lost, but also to mark it as being migrated.
	$update->execute($row->{state}, $row->{creation_ts}, $row->{modified_ts}, $row->{id});
	$insert->execute($row->{id}, "Status", $row->{value});
    }
    print "Migrated $count records.\n" if $count > 0;

    # Now do the same for the commentstatehistory records.
    $stmt = $dbh->prepare_cached('SELECT id, state, version, modified_ts ' .
				 'FROM commentstatehistory ' .
				 'WHERE state >= 0');
    $stmt->execute();
    
    $update = $dbh->prepare_cached('UPDATE commentstatehistory ' .
				   'SET metric_name = ?, metric_value = ?, ' .
				   ' state = ?, modified_ts = ? ' .
				   'WHERE id = ? AND version = ?');
    $count = 0;
    @update_rows = ();
    while (my ($id, $state, $version, $modified_ts) =
	   $stmt->fetchrow_array()) {
	print "Migrating old commentstatehistory records...\n" if $count == 0;
	my $value = $old_comment_states[$state];
	$value = "Unknown $state" unless defined $value;

	push @update_rows, { value=>$value, state=>-$state -1,
			     modified_ts=>$modified_ts, id=>$id,
			     version=>$version };
	$count++;
    }
    $stmt->finish();

    foreach my $row (@update_rows) {
	$update->execute("Status", $row->{value}, $row->{state},
			 $row->{modified_ts}, $row->{id},
			 $row->{version});
    }
    print "Migrated $count records.\n" if $count > 0;
    $database->commit();
};
if ($@) {
    print "Failed because of $@\n";
}

$dbh->{PrintError} = 1;

# Now generate the contents of the codestriker.pl file, with the appropriate
# configuration details set (basically, the location of the lib dir).
print "Generating cgi-bin/codestriker.pl file...\n";
mkdir '../cgi-bin', 0755;
open(CODESTRIKER_BASE, "codestriker.pl.base")
    || die "Unable to open codestriker.pl.base file: $!";
open(CODESTRIKER_PL, ">../cgi-bin/codestriker.pl")
    || die "Unable to create ../cgi-bin/codestriker.pl file: $!";
my $codestriker_lib = 'use lib \'' . cwd() . '/../lib\';';
for (my $i = 0; <CODESTRIKER_BASE>; $i++) {

    # Check if this line requires any config substitutions.
    my $line = $_;
    $line =~ s/\@CODESTRIKER_LIB_DECLARATION\@/$codestriker_lib/g;
    print CODESTRIKER_PL $line;

    if ($i == 0) {
	# Print out a message indicating this is an auto-generated file.
	print CODESTRIKER_PL "\n# !!!! THIS FILE IS AUTO-GENERATED by bin/checksetup.pl !!!\n";
	print CODESTRIKER_PL "# !!!! DO NOT EDIT !!!\n";

	print CODESTRIKER_PL "# The base source is bin/codestriker.pl.base.\n";
    }
}
close CODESTRIKER_BASE;
close CODESTRIKER_PL;

# Make sure the generated file is executable.
chmod 0755, '../cgi-bin/codestriker.pl';

# Clean out the contents of the data and template directory, but don't
# remove them.
print "Removing old generated templates...\n";
chdir('../cgi-bin') ||
    die "Couldn't change to cgi-dir directory: $!";
if (-d 'template/en') {
    print "Cleaning old template directory...\n";
    rmtree(['template/en'], 0, 1);
}

print "Done\n";

# Release the database connection.
$database->release_connection();


