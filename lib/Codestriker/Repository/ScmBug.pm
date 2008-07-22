###############################################################################
# Codestriker: Copyright (c) 2001,2002,2003 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# ScmBug repository access package.

package Codestriker::Repository::ScmBug;

use strict;

# Optional dependencies for people who don't require ScmBug functionality.
eval("use Scmbug::ActivityUtilities");

# Create a connection to the ScmBug daemon, and maintain a reference to the
# delegate repository.
sub new {
    my ($type, $hostname, $port, $repository) = @_;
    
    my $self = {};
    $self->{repository} = $repository;
    $self->{scmbug} = Scmbug::ActivityUtilities->new($hostname, $port);

    bless $self, $type;
}


# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    $self->{repository}->retrieve($filename, $revision, $content_array_ref);
}

# Retrieve the "root" of this repository.
sub getRoot ($) {
    my ($self) = @_;
    return $self->{repository}->{repository_url};
}

# Return a URL which views the specified file and revision.
sub getViewUrl ($$$) {
    my ($self, $filename, $revision) = @_;

    return $self->{repository}->getViewUrl($filename, $revision);
}

# Return a string representation of this repository.
sub toString ($) {
    my ($self) = @_;
    return $self->{repository}->toString();
}

# The getDiff operation, pull out a change set based on the bug IDs.
sub getDiff {
    my ($self, $bugids, $stdout_fh, $stderr_fh, $default_to_head) = @_;

    # Remove spaces from the comma-separated list of bug ids so that
    # "123, 456" is transformed to "123,456" which is the form
    # Scmbug::ActivityUtilities expects.
    $bugids =~ s/ //g;
    my $affected_files_list = $self->{scmbug}->get_affected_files($bugids);

    foreach my $changeset ( @{ $affected_files_list } ) {
	
	# Don't diff just directory property changes
	if( $changeset->{file} =~ /\/$/ ) {
	    next;
	}

	# Call the delgate repository object for retrieving the actual
	# content.
	my $old_rev = ($changeset->{old} == 0) ? "" : $changeset->{old};
	my $new_rev = ($changeset->{new} == 0) ? "" : $changeset->{new};		
	my $ret = $self->{repository}->getDiff($old_rev, $new_rev,
					       $changeset->{file},
					       $stdout_fh,
					       $stderr_fh,
					       $default_to_head);
	return $ret if $ret != $Codestriker::OK;
    }

    return $Codestriker::OK;
}


1;
