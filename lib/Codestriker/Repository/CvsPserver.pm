###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# CVS repository class with access to a pserver repository.

package Codestriker::Repository::CvsPserver;

use strict;
use IPC::Run;

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
    open(CVS, "$Codestriker::cvs -q -d " . $self->{url} .
	 " co -p -r $revision $filename |")
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
    my $viewer = $Codestriker::file_viewer->{$self->{url}};
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

    my @command = ( $Codestriker::cvs, '-q', '-d', $self->{url},
		    'rdiff', '-u', '-r', $start_tag, '-r', $end_tag,
		    $module_name );

    # Note, under Windows 98, ">$error_file" doesn't work as the final
    # parameters to IPC::Run::run, so open the file explicitly.
    open ERROR, ">$error_file" || die "Can't create error file: $!";
    my $h = IPC::Run::run(\@command, '>', $fh, '2>', \*ERROR);
    close ERROR;

    return $Codestriker::OK;
}

1;
