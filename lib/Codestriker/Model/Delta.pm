###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling topic file data.

package Codestriker::Model::Delta;

use strict;

# Create the appropriate delta rows for this review. This gets called
# by File::get_deltas. It passes in the result of a sql query on the
# delta table.
sub new {
    my $class = shift;
    my $self = {};
    bless $self;
    
    $self->{filename} = $_[1];
    $self->{revision} = $_[2];
    $self->{binary} = $_[3];
    $self->{old_linenumber} = $_[4];
    $self->{new_linenumber} = $_[5];
    $self->{text} = $_[6];
    $self->{description} = $_[7];
    $self->{filenumber} = $_[8];
    $self->{repmatch} = $_[9];
    $self->{only_delta_in_file} = 0;
    
    return $self;
}

# Retrieve the ordered list of deltas applied to a specific file. class factory
# method, returns a list of delta objects.
sub get_deltas($$) {
    my ($topicid, $filenumber) = @_;
    
    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Setup the appropriate statement and execute it.
    my $select_deltas =
	$dbh->prepare_cached('SELECT delta_sequence, filename, revision, ' .
			     'binaryfile, old_linenumber, new_linenumber, ' .
			     'deltatext, description, topicfile.sequence, ' .
			     'repmatch FROM topicfile, delta ' .
			     'WHERE delta.topicid = ? AND ' .
			     'delta.topicid = topicfile.topicid AND ' .
			     'delta.file_sequence = topicfile.sequence ' .
			     (($filenumber != -1) ?
			      'AND topicfile.sequence = ? ' : '').
			     'ORDER BY delta_sequence ASC');
    
    my $success = defined $select_deltas;
    if ($filenumber != -1) {
	$success &&= $select_deltas->execute($topicid, $filenumber);
    } else {
	$success &&= $select_deltas->execute($topicid);
    }
    
    # Store the results into an array of objects.
    my @results = ();
    if ($success) {
	my @data;
	while (@data = $select_deltas->fetchrow_array()) {
            my $delta = Codestriker::Model::Delta->new( @data );
	    push @results, $delta;
	}
    }
    
    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;
    
    return @results;
}

# This function looks at the delta, and will return 1 if the delta looks like
# it is a delta for a completly new file. This happens when a new file is added
# to SCM system, or the user updated a plain old text document to be reviewed
# without diffs. We need this function because we want to format this case
# special.
sub is_delta_new_file
{
    my $self = shift;
    
    # All of the following must be true:
    # - one delta for the entire file
    # - delta must start at line 1 (0ld, and new)
    my $is_new_file = 0;
    if ($self->{only_delta_in_file} &&
	$self->{old_linenumber} == 1 &&
	$self->{new_linenumber} == 1) {
	# All of the delta text lines must start with +.
	my @lines = split '\n', $self->{text};
	if ( scalar( grep !/^\+/, @lines ) == 0) {
	    $is_new_file = 1;
	}
    }
    
    return $is_new_file;
}

1;
