#!/usr/bin/perl -w

###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Script to import an existing codestriker repository (<= 1.4.X) into a
# Codestriker database.  It is assumed when this script is run, that the
# database is up and running already.  Note most of this code came from
# the 1.4.X codestriker.

use strict;

use lib '../lib';
use Codestriker;
use Codestriker::Model::Topic;
use Codestriker::Model::Comment;

# Prototypes.
sub main();
sub usage();

main();

sub main() {
    # Check that the right number of arguments have been passed in.
    if ($#ARGV != 0) {
	usage();
	exit 1;
    }

    # Check that the directory argument is valid.
    my $dir = $ARGV[0];
    if (! -e $dir) {
	print "\"$dir\" does not exist.\n";
	exit 1;
    }
    if (! -d $dir) {
	print "\"$dir\" is not a directory.\n";
	exit 1;
    }

    # Make sure the database is configured correctly, and is uptodate.
    system("./checksetup.pl");

    # Initialise Codestriker, load up the configuration file.
    Codestriker->initialise();

    opendir DIR, "$dir" || die "Can't examine directory \"$dir\": $!";
    my @allfiles = readdir DIR;
    foreach my $file (@allfiles) {
	if (-d "$dir/$file" && $file =~ /^(\d+)$/) {
	    my $topicid = $1;
	    print "Processing topic $topicid...\n";

	    # Open and parse the document file.
	    open(DOCUMENT, "$dir/$file/document")
		|| die "Can't open document file: $!";

	    # Retrieve the time the topic was created.
	    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
		$atime,$mtime,$ctime,$blksize,$blocks) = stat DOCUMENT;
	    my $document_ts = Codestriker->get_timestamp($mtime);

	    # The document text.
	    my $document_text = "";

            # The document title.
	    my $document_title = "";
	    
            # The associated document bug number.
	    my $document_bug_ids = "";

            # The document description.
	    my $document_description = "";

            # The document reviewers.
	    my $document_reviewers = "";

            # The Cc list to be informed of the new topic.
	    my $document_cc = "";
	    
            # The document author.
	    my $document_author = "";
	    
	    # Parse the document metadata.
	    while (<DOCUMENT>) {
		my $data = $_;
		if ($data =~ /^Author: (.+)$/o) {
		    $document_author = $1;
		} elsif ($data =~ /^Title: (.+)$/o) {
		    $document_title = $1;
		} elsif ($data =~ /^Bug: (.*)$/o) {
		    $document_bug_ids = $1;
		} elsif ($data =~ /^Reviewers: (.+)$/o) {
		    $document_reviewers = $1;
		} elsif ($data =~ /^Cc: (.+)$/o) {
		    $document_cc = $1;
		} elsif ($data =~ /^Description: (\d+)$/o) {
		    my $description_length = $1;
		    
		    # Read the document description.
		    for (my $i = 0; $i < $description_length; $i++) {
			my $data = <DOCUMENT>;
			$document_description .= $data;
		    }
		} elsif ($data =~ /^Text$/) {
		    last;
		}
		# Silently ignore unknown fields.
	    }
	    
	    # Read the document data itself.
	    while (<DOCUMENT>) {
		$document_text .= $_;
	    }
	    close DOCUMENT;

	    # Now read the comments file.

            # Indexed by comment number.  Contains the line number the
            # comment is about.
	    my @comment_linenumber = ();

            # Indexed by comment number.  Contains the comment data.
	    my @comment_data = ();

            # Indexed by comment number.  Contains the comment author.
	    my @comment_author = ();

            # Indexed by comment number.  Contains the comment date.
	    my @comment_date = ();

	    open(COMMENTS, "$dir/$file/comments")
		|| die "Unable to open comment file: $!";

	    while (<COMMENTS>) {
		# Read the metadata for the comment.
		/^(\d+) (\d+) ([-_\@\w\.]+) (.*)$/o;
		my $comment_size = $1;
		my $linenumber = $2;
		my $author = $3;
		my $datestring = $4;
		
		push @comment_linenumber, $linenumber;
		push @comment_author, $author;
		push @comment_date, $datestring;
		my $comment_text = "";
		for (my $i = 0; $i < $comment_size; $i++) {
		    $comment_text .= <COMMENTS>;
		}
		push @comment_data, $comment_text;
	    }
	    close COMMENTS;
	    
	    # Now write the topic information to the database.
	    my $bug_ids = join ', ', (split / /, $document_bug_ids);
	    Codestriker::Model::Topic->create($topicid, $document_author,
					      $document_title,
					      $bug_ids,
					      $document_reviewers,
					      $document_cc,
					      $document_description,
					      $document_text,
					      $document_ts);

	    # Now create each comment.
	    my $comment_ts;
	    for (my $i = 0; $i <= $#comment_author; $i++) {
		my $date = $comment_date[$i];
		$date =~ /^(\d\d):(\d\d):(\d\d) \w+, (\d+) (\w+), (\d+)$/
		    || die "Unable to parse comment date: \"$date\"\n";
		my $hour = $1;
		my $min = $2;
		my $sec = $3;
		my $mday = $4;
		my $month_name = $5;
		my $year = $6;

		# Convert the month into its number.  Note the old codestriker
		# mis-spelt February!
		my $month = 0;
		if ($month_name eq "Februrary") {
		    $month = 2;
		} else {
		    my $m = 0;
		    for ($m = 0; $m < 12; $m++) {
			if ($Codestriker::months[$m] eq $month_name) {
			    $month = $m+1;
			    last;
			}
		    }
		    if ($m == 12) {
			die "Couldn't parse month \"$month_name\" in comment";
		    }
		}

		$comment_ts = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
				      $year, $month, $mday,
				      $hour, $min, $sec);

		# Now actually create the comment.
		Codestriker::Model::Comment->create($topicid,
						    $comment_linenumber[$i],
						    $comment_author[$i],
						    $comment_data[$i],
						    $comment_ts);
	    }

	    # The last comment will be the most recent.  Change the topic's
	    # state to CLOSED and the last modified date to the last comment.
	    # if there are no comments, the date will be the same as the
	    # creation date of the topic.
	    my $ts = ($#comment_author >= 0) ? $comment_ts : $document_ts;
	    Codestriker::Model::Topic->change_state($topicid, "Closed", $ts,
						    0);
	}
    }
}

sub usage() {
    print "./import.pl <codestriker-dir>\n";
}
