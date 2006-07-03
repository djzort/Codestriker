###############################################################################
# Codestriker: Copyright (c) 2004 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Handler for ClearCase Dynamic Views.
# Contributed by "Avinandan Sengupta" <avinna_seng at users.sourceforge.net>.

package Codestriker::Repository::ClearCaseDynamic;

use strict;
use File::Spec;

# Put this in an eval block so that this becomes an optional dependency for
# those people who don't use this module.
eval("use ClearCase::CtCmd");

# Constructor.
# viewname:vobs_dir - absolute path to the vobs dir
#                     (mount point on unix/drive letter on windows)
# This dynamic view should be mounted on the same host on which Codestriker
# is running.
sub new ($$)
{
    my ($type, $url) = @_;

    my $self = {};
    $_ = $url;
    
    /(.*):(.*)/;
    $self->{dynamic_view_name} = $1;
    $self->{vobs_dir} = $2;

    bless $self, $type;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$)
{
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Set the current view to the repository's dynamic view name.
    my $clearcase = ClearCase::CtCmd->new();
    (my $status, my $stdout, my $error_msg) =
	$clearcase->exec('setview', $self->{dynamic_view_name});

    # Check the result of the setview command.
    if ($status) {
	$error_msg = "Failed to open view: " . $self->{dynamic_view_name} .
	    ": $error_msg\n";
	print STDERR "$error_msg\n";
	return $error_msg;
    }

    # Execute the remaining code in an eval block to ensure the endview
    # command is always called.
    eval {
	# Construct the filename in the view, based on its path and
	# revision.
	my $full_element_name = File::Spec->catfile($self->{vobs_dir},
						    $filename);
	if (defined($revision) && length($revision) > 0) {
	    $full_element_name = $full_element_name . '@@' . $revision;
	}

	# Load the file directly into the given array.
	open (CONTENTFILE, "$full_element_name")
	    || die "Couldn't open file: $full_element_name: $!";
	for (my $i = 1; <CONTENTFILE>; $i++) {
	    chop;
	    $$content_array_ref[$i] = $_;
	}
	close CONTENTFILE;
    };
    if ($@) {
	# Something went wrong in the above code, record the error message
	# and continue to ensure the view is closed.
	$error_msg = $@;
	print STDERR "$error_msg\n";
    }

    # Close the view.
    ($status, $stdout, $error_msg) =
	$clearcase->exec('endview', $self->{dynamic_view_name});
    if ($status) {
	$error_msg = "Failed to close view: " . $self->{dynamic_view_name} .
	    ": $error_msg\n";
	print STDERR "$error_msg\n";
    }
    
    return $error_msg;
}

# Retrieve the "root" of this repository.
sub getRoot ($) {
    my ($self) = @_;
    return $self->{vobs_dir};
}

# Return a URL which views the specified file and revision.
sub getViewUrl ($$$) {
    my ($self, $filename, $revision) = @_;

    # Lookup the file viewer from the configuration.
    my $viewer = $Codestriker::file_viewer->{$self->toString()};
    return (defined $viewer) ? $viewer . "/" . $filename : "";
}

# Return a string representation of this repository.
sub toString ($) {
    my ($self) = @_;
    return "clearcase:dyn:" . $self->{dynamic_view_name} . ":" . $self->{vobs_dir};
}

# Given a start tag, end tag and a module name, store the text into
# the specified file handle.  If the size of the diff goes beyond the
# limit, then return the appropriate error code.
sub getDiff ($$$$$$) {
    my ($self, $start_tag, $end_tag, $module_name, $fh, $stderr_fh) = @_;

    return $Codestriker::UNSUPPORTED_OPERATION;
}

1;
