###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling comment data.

package Codestriker::Model::Comment;

use strict;
use Encode qw(decode_utf8);

use Codestriker::DB::DBI;

sub new {
    my $class = shift;
    my $self = {};

    $self->{id} = 0;
    $self->{topicid} = 0;
    $self->{fileline} = 0;
    $self->{filenumber} = 0;
    $self->{filenew} = 0;
    $self->{author} = '';
    $self->{data} = '';
    $self->{date} = Codestriker->get_timestamp(time);
    $self->{version} = 0;
    $self->{db_creation_ts} = "";
    $self->{db_modified_ts} = "";
    $self->{creation_ts} = "";
    $self->{modified_ts} = "";
    $self->{metrics} = undef;

    bless $self, $class;
    return $self;
}

# Create a new comment with all of the specified properties.  Ensure that the
# associated commentstate record is created/updated.
sub create {
    my ($self, $topicid, $fileline, $filenumber, $filenew, $author, $data,
        $metrics) = @_;

    my $timestamp = Codestriker->get_timestamp(time);

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Check if a comment has been made against this line before.
    my $select_commentstate =
      $dbh->prepare_cached('SELECT version, id ' .
                           'FROM commentstate ' .
                           'WHERE topicid = ? AND fileline = ? AND '.
                           'filenumber = ? AND filenew = ?');
    my $success = defined $select_commentstate;
    $success &&= $select_commentstate->execute($topicid, $fileline,
                                               $filenumber, $filenew);
    my $commentstateid = 0;
    my $version = 0;
    my $creation_ts = "";
    if ($success) {
        ($version, $commentstateid) =
          $select_commentstate->fetchrow_array();
        $success &&= $select_commentstate->finish();
        if (! defined $version) {
            # A comment has not been made on this particular line yet,
            # create the commentstate row now.  Note the old column of
            # state has its value set to -100 so the data migration code
            # in checksetup.pl knows this is a new row that can be
            # ignored.
            $creation_ts = $timestamp;
            my $insert = $dbh->prepare_cached('INSERT INTO commentstate ' .
                                              '(topicid, fileline, ' .
                                              'filenumber, filenew, ' .
                                              'state, version, creation_ts, ' .
                                              'modified_ts) VALUES ' .
                                              '(?, ?, ?, ?, ?, ?, ?, ?)');
            $success &&= defined $insert;
            $success &&= $insert->execute($topicid, $fileline, $filenumber,
                                          $filenew, -100, 0,
                                          $creation_ts, $creation_ts);
            $success &&= $insert->finish();
        } else {
            # Update the commentstate record.
            my $update = $dbh->prepare_cached('UPDATE commentstate SET ' .
                                              'version = ?, ' .
                                              'modified_ts = ? ' .
                                              'WHERE topicid = ? AND ' .
                                              'fileline = ? AND ' .
                                              'filenumber = ? AND ' .
                                              'filenew = ?');
            $success &&= defined $update;
            $success &&= $update->execute(++$version,
                                          $timestamp,
                                          $topicid, $fileline, $filenumber,
                                          $filenew);
            $success &&= $update->finish();
        }

        # Determine the commentstateid that may have been just created.
        $success &&= $select_commentstate->execute($topicid, $fileline,
                                                   $filenumber, $filenew);
        if ($success) {
            ($version, $commentstateid) =
              $select_commentstate->fetchrow_array();
        }
        $success &&= $select_commentstate->finish();

        # Create the comment record.
        my $insert_comment =
          $dbh->prepare_cached('INSERT INTO commentdata ' .
                               '(commentstateid, '.
                               'commentfield, author, creation_ts) ' .
                               'VALUES (?, ?, ?, ?)');
        my $success = defined $insert_comment;

        # Create the comment row.
        $success &&= $insert_comment->execute($commentstateid, $data,
                                              $author, $timestamp);
        $success &&= $insert_comment->finish();

        # Now handle any commentmetric rows.
        update_comment_metrics($commentstateid, $metrics, $dbh);
    }

    $self->{id} = $commentstateid;
    $self->{topicid} =  $topicid;
    $self->{fileline} = $fileline;
    $self->{filenumber} = $filenumber;
    $self->{filenew} = $filenew;
    $self->{author} = $author;
    $self->{data} = $data;
    $self->{date} = $timestamp;
    $self->{version} = $version;
    $self->{db_creation_ts} = $creation_ts;
    $self->{creation_ts} = Codestriker->format_timestamp($creation_ts);
    $self->{db_modified_ts} = $timestamp;
    $self->{modified_ts} = Codestriker->format_timestamp($timestamp);

    # Update the metrics into the object as a hash.
    foreach my $metric (@{ $metrics }) {
        $self->{metrics}->{$metric->{name}} = $metric->{value};
    }

    # Get the filename, for the new comment.
    my $get_filename = $dbh->prepare_cached('SELECT filename ' .
                                            'FROM topicfile ' .
                                            'WHERE topicid = ? AND ' .
                                            'sequence = ?');
    $success &&= defined $get_filename;
    $success &&= $get_filename->execute($topicid, $filenumber);

    ( $self->{filename} ) = $get_filename->fetchrow_array();

    $select_commentstate->finish();
    $get_filename->finish();

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr if !$success;
}


# Update the comment metrics for a specific commentstate.  Note the rows for
# a specific metric may or may not already exist.
sub update_comment_metrics {
    my ($commentstateid, $metrics, $dbh) = @_;

    # Now create any necessary commentmetric rows.  Note its possible this
    # may refer to existing data which needs to be updated, or could be
    # new metric data.
    eval {
        if (defined $metrics) {
            foreach my $metric (@{ $metrics }) {
                # Check if a value for this metric name has been created
                # already.
                my $select_metric =
                  $dbh->prepare_cached('SELECT COUNT(id) ' .
                                       'FROM commentstatemetric ' .
                                       'WHERE id = ? AND name = ?');
                $select_metric->execute($commentstateid, $metric->{name});
                my $count;
                ($count) = $select_metric->fetchrow_array();
                $select_metric->finish();
                if ($count == 0) {
                    # Need to create a new row for this metric.
                    my $insert_metric =
                      $dbh->prepare_cached('INSERT INTO commentstatemetric '.
                                           '(id, name, value) VALUES ' .
                                           '(?, ?, ?)');
                    $insert_metric->execute($commentstateid, $metric->{name},
                                            $metric->{value});
                    $insert_metric->finish();
                } else {
                    # Need to update this row for this metric.
                    my $update_metric =
                      $dbh->prepare_cached('UPDATE commentstatemetric ' .
                                           'SET value = ? ' .
                                           'WHERE id = ? AND name = ?');
                    $update_metric->execute($metric->{value}, $commentstateid,
                                            $metric->{name});
                    $update_metric->finish();
                }
            }
        }
    };
    if ($@) {
        warn "Unable to update comment state metric data because $@\n";
        eval { $dbh->rollback() };
    }
}

# This function returns as a list the authors emails address that have entered
# comments against a topic.
sub read_authors
  {
      my ($type, $topicid ) = @_;

      # Obtain a database connection.
      my $dbh = Codestriker::DB::DBI->get_connection();

      # Store the results into an array of objects.
      my @results;

      # Retrieve all of the comment information for the specified topicid.
      my $select_comment =
        $dbh->prepare_cached('SELECT distinct(commentdata.author) ' .
                             'FROM commentdata, commentstate ' .
                             'WHERE commentstate.topicid = ? AND ' .
                             'commentstate.id = commentdata.commentstateid ');

      my $success = defined $select_comment;
      my $rc = $Codestriker::OK;
      $success &&= $select_comment->execute($topicid);

      # Store the results into the referenced arrays.
      if ($success) {
          my @data;
          while (@data = $select_comment->fetchrow_array()) {
              push @results, $data[0];
          }
          $select_comment->finish();
      }

      Codestriker::DB::DBI->release_connection($dbh, $success);
      die $dbh->errstr unless $success;

      return @results;
  }

# Return all of the comments made for a specified topic. This should only be
# called be called by the Topic object.
sub read_all_comments_for_topic($$) {
    my ($type, $topicid) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Determine if we are using Oracle, since it can't handle LEFT OUTER JOINs.
    my $using_oracle = $Codestriker::db =~ /^DBI:Oracle/i;

    # Store the results into an array of objects.
    my @results = ();

    # Retrieve all of the comment information for the specified topicid.
    my $select_comment =
      $dbh->prepare_cached('SELECT commentdata.commentfield, ' .
                           'commentdata.author, ' .
                           'commentstate.fileline, ' .
                           'commentstate.filenumber, ' .
                           'commentstate.filenew, ' .
                           'commentdata.creation_ts, ' .
                           'topicfile.filename, ' .
                           'commentstate.version, ' .
                           'commentstate.id, ' .
                           'commentstate.creation_ts, ' .
                           'commentstate.modified_ts ' .
                           'FROM commentdata, commentstate ' .
                           ($using_oracle ?
                            (', topicfile WHERE commentstate.topicid = ? ' .
                             'AND commentstate.id = commentdata.commentstateid ' .
                             'AND topicfile.topicid = commentstate.topicid(+) ' .
                             'AND topicfile.sequence = commentstate.filenumber(+) ') :
                            ('LEFT OUTER JOIN topicfile ON ' .
                             'commentstate.topicid = topicfile.topicid AND ' .
                             'commentstate.filenumber = topicfile.sequence ' .
                             'WHERE commentstate.topicid = ? ' .
                             'AND commentstate.id = commentdata.commentstateid ')) .
                           'ORDER BY ' .
                           'commentstate.filenumber, ' .
                           'commentstate.fileline, ' .
                           'commentstate.filenew, ' .
                           'commentdata.creation_ts');
    my $success = defined $select_comment;
    my $rc = $Codestriker::OK;
    $success &&= $select_comment->execute($topicid);

    # Store the results into the referenced arrays.
    if ($success) {
        my @data;
        while (@data = $select_comment->fetchrow_array()) {
            my $comment = Codestriker::Model::Comment->new();
            $comment->{topicid} =  $topicid;
            $comment->{data} = decode_utf8($data[0]);
            $comment->{author} = $data[1];
            $comment->{fileline} = $data[2];
            $comment->{filenumber} = $data[3];
            $comment->{filenew} = $data[4];
            $comment->{date} = Codestriker->format_timestamp($data[5]);
            $comment->{filename} = decode_utf8($data[6]);
            $comment->{version} = $data[7];
            $comment->{id} = $data[8];
            $comment->{db_creation_ts} = $data[9];
            $comment->{creation_ts} = Codestriker->format_timestamp($data[9]);
            $comment->{db_modified_ts} = $data[10];
            $comment->{modified_ts} = Codestriker->format_timestamp($data[10]);
            push @results, $comment;
        }
        $select_comment->finish();
    }

    # Now for each comment returned, retrieve the comment metrics data as well.
    foreach my $comment (@results) {
        my $select_metric =
          $dbh->prepare_cached('SELECT name, value ' .
                               'FROM commentstatemetric ' .
                               'WHERE id = ?');
        $select_metric->execute($comment->{id});
        my %metrics = ();
        my @data;
        while (@data = $select_metric->fetchrow_array()) {
            $metrics{$data[0]} = $data[1];
        }
        $select_metric->finish();

        # Update this comment update with the list of metrics associated with
        # it.
        $comment->{metrics} = \%metrics;
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);

    return @results;
}

# Return all of the comments made for a specified topic filtered by
# author and metric values.  If a filter parameter is not defined, then
# it is ignored.
sub read_filtered {
    my ($type, $topicid, $filtered_by_author, $metric_filter) = @_;

    my %metric_filter = %{ $metric_filter };

    # Read all of the comments from the database.
    my @comments = $type->read_all_comments_for_topic($topicid);

    # Now filter out comments that don't match the author and metric
    # filter.
    @comments = grep {
        my $comment = $_;
        my $keep_comment = 1;

        # Check for filters via the comment author name, handle email
        # SPAM filtering.
        my $filteredAuthor =
          Codestriker->filter_email($comment->{author});
        my $filteredByAuthor =
          Codestriker->filter_email($filtered_by_author);

        if (defined $filteredByAuthor && $filteredByAuthor ne "" &&
            $filteredAuthor ne $filteredByAuthor) {
            # Don't keep this record.
            $keep_comment = 0;
        } else {
            # Check if the metric values match for each key.
            foreach my $metric (keys %metric_filter) {
                if ($comment->{metrics}->{$metric} ne
                    $metric_filter{$metric}) {
                    $keep_comment = 0;
                    last;
                }
            }
        }

        # Indicate whether this comment should be kept or not.
        $keep_comment;
    } @comments;

    return @comments;
}

# Update the specified metric for the specified commentstate.  The version
# parameter indicates what version of the commentstate the user was operating
# on.
sub change_state {
    my ($self, $metric_name, $metric_value, $version) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    my $timestamp = Codestriker->get_timestamp(time);

    # Check that the version reflects the current version in the DB.
    my $select_comments =
      $dbh->prepare_cached('SELECT id, version ' .
                           'FROM commentstate ' .
                           'WHERE topicid = ? AND fileline = ? AND ' .
                           'filenumber = ? AND filenew = ?');
    my $update_comments =
      $dbh->prepare_cached('UPDATE commentstate SET version = ?, ' .
                           'modified_ts = ? ' .
                           'WHERE id = ?');

    my $success = defined $select_comments && defined $update_comments;
    my $rc = $Codestriker::OK;

    # Retrieve the current comment data.
    $success &&= $select_comments->execute($self->{topicid},
                                           $self->{fileline},
                                           $self->{filenumber},
                                           $self->{filenew});

    # Make sure that the topic still exists, and is therefore valid.
    my ($id, $current_version);
    if ($success &&
        ! (($id, $current_version)
           = $select_comments->fetchrow_array())) {
        # Invalid topic id.
        $success = 0;
        $rc = $Codestriker::INVALID_TOPIC;
    }
    $success &&= $select_comments->finish();

    # Check the version number.
    if ($success && $version != $self->{version}) {
        $success = 0;
        $rc = $Codestriker::STALE_VERSION;
    }

    # Now update the version number for commentstate.
    $self->{version} = $self->{version} + 1;
    $self->{metrics}->{$metric_name} = $metric_value;
    $self->{modified_ts} = Codestriker->format_timestamp($timestamp);
    $success &&= $update_comments->execute($self->{version},
                                           $timestamp,
                                           $id);

    # Now update the commentstatemetric row for this metric.
    my $metrics = [ { name => $metric_name, value => $metric_value } ];
    update_comment_metrics($id, $metrics, $dbh);

    Codestriker::DB::DBI->release_connection($dbh, $success);

    return $rc;
}

1;
