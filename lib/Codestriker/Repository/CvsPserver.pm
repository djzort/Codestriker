###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# CVS repository class with access to a pserver repository.

package Codestriker::Repository::CvsPserver;

use strict;

# Constructor, which takes as a parameter the username, password, hostname
# and repository path.
sub new ($$$$$) {
    my ($type, $username, $password, $hostname, $cvsroot) = @_;

    my $self = {};
    $self->{username} = $username;
    $self->{password} = $password;
    $self->{hostname} = $hostname;
    $self->{cvsroot} = $cvsroot;
    $self->{url} = ":pserver:${username}:${password}\@${hostname}:${cvsroot}";
    bless $self, $type;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Open a pipe to the local CVS repository.
    open(CVS, "$Codestriker::cvs -d " . $self->{url} .
	 " co -p -r $revision $filename 2>/dev/null |")
	|| die "Can't open connection to pserver CVS repository: $!";

    # Read the data.
    for (my $i = 1; <CVS>; $i++) {
	chop;
	$$content_array_ref[$i] = $_;
    }
    close CVS;
}

# Retrieve the "root" of this repository.
sub getRoot ($) {
    my ($self) = @_;
    return $self->{cvsroot};
}

# Return a URL which views the specified file and revision.
sub getViewUrl ($$$) {
    my ($self, $filename, $revision) = @_;

    # Lookup the file viewer from the configuration.
    my $viewer = $Codestriker::file_viewer->{$self->{cvsroot}};
    return (defined $viewer) ? $viewer . "/" . $filename : "";
}

# Return a string representation of this repository.
sub toString ($) {
    my ($self) = @_;
    return $self->{url};
}

# Given a start tag, end tag and a module name, store the text into
# the specified file handle.  If the size of the diff goes beyond the
# limit, then return the appropriate error code.
sub getDiff ($$$$$) {
    my ($self, $start_tag, $end_tag, $module_name, $fh, $error_file) = @_;

    open(CVS, "$Codestriker::cvs -d " . $self->{cvsroot} .
	 " rdiff -u -r $start_tag -r $end_tag $module_name 2> $error_file |")
	|| die "Can't open connection to local CVS repository: $!";
    my $length = 0;
    while (<CVS>) {
	print $fh $_;
	$length += length $_;
	if ($length > $Codestriker::DIFF_SIZE_LIMIT) {
	    return $Codestriker::DIFF_TO_BIG;
	}
    }
    return $Codestriker::OK;
}

1;
