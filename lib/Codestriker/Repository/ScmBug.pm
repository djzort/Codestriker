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
eval("use XML::Simple");
eval("use Scmbug::Connection");
eval("use Scmbug::Common");

# Create a connection to the ScmBug daemon, and maintain a reference to the
# delegate repository.
sub new {
    my ($type, $hostname, $port, $repository) = @_;
    
    my $self = {};
    $self->{repository} = $repository;
    $self->{connection} = Scmbug::Connection->new(0);
    $self->{connection}->location($hostname);
    $self->{connection}->port($port);

    bless $self, $type;
}


#
# Retrieve affected files in XML format from the ScmBug daemon.
#
sub get_affected_files_XML {
    my $self = shift;
    my $bugids = shift;

    my $new_activity = Scmbug::Activity->new();
    $new_activity->{name} = $ScmBug::Common::ACTIVITY_GET_AFFECTED_FILES;
    $new_activity->{user} = "codestriker";
    
    # Comma seperated list of bugs
    $new_activity->{bugs} = $bugids;

    # Process this tagging activity as well
    my $affected_files = $self->{connection}->process_activity($new_activity);

    return $affected_files;
}

#
# Convert the XML format to a nice Perl structured format
# grouping all the files together
#
sub convert_from_xml {
    my $self = shift;
    my $affected_files_xml = shift;
    
    my $xml = new XML::Simple (NoAttr=>1);
    my $raw = $xml->XMLin($affected_files_xml);
    
    my @changeList = ();
    
    my $bugid;
    foreach $bugid (keys %{$raw}) {
    	my $comment_section;
    	foreach $comment_section (keys %{$raw->{$bugid}}) {
    	    my $file_change;
    	    foreach $file_change (keys %{$raw->{$bugid}->{$comment_section}}) {
	        my $changeset;
	        $changeset->{file} = $raw->{$bugid}->{$comment_section}->{$file_change}->{filename};
	        $changeset->{new} = $raw->{$bugid}->{$comment_section}->{$file_change}->{new_version};
	        $changeset->{old} = $raw->{$bugid}->{$comment_section}->{$file_change}->{old_version};

		# Set the old version for new files to 0
		if( "$changeset->{old}" eq "NONE" ) {
		    $changeset->{old} = 0;
		}
		if( "$changeset->{new}" eq "NONE" ) {
		    $changeset->{new} = 0;
		}
		push @changeList, $changeset;
    	    }
    	}
    }
    
    return \@changeList;
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

    my $affected_files_list =
	$self->convert_from_xml($self->get_affected_files_XML($bugids));


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
