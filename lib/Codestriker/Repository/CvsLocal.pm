###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# CVS repository class with access to a local repository.

package Codestriker::Repository::CvsLocal;

use strict;
use IPC::Open3;

# Constructor, which takes as a parameter the CVSROOT.
sub new ($$$) {
    my ($type, $cvsroot, $prefix) = @_;

    my $self = {};
    $self->{cvsroot} = $cvsroot;
    $self->{prefix} = $prefix;
    bless $self, $type;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Open a pipe to the local CVS repository.
    open(CVS, "\"$Codestriker::cvs\" -q -d " . $self->{prefix} . $self->{cvsroot} .
	 " co -p -r $revision $filename |")
	|| die "Can't execute CVS command: $!";
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
    return $self->{prefix} . $self->{cvsroot};
}

# Given a start tag, end tag and a module name, store the text into
# the specified file handle.  If the size of the diff goes beyond the
# limit, then return the appropriate error code.
sub getDiff ($$$$$$) {
    my ($self, $start_tag, $end_tag, $module_name,
	$stdout_fh, $stderr_fh) = @_;

    my $write_stdin_fh = new FileHandle;
    my $read_stdout_fh = new FileHandle;
    my $read_stderr_fh = new FileHandle;

    my $pid = open3($write_stdin_fh, $read_stdout_fh, $read_stderr_fh,
		    $Codestriker::cvs, '-q', '-d', $self->{cvsroot},
		    'rdiff', '-u', '-r', $start_tag, '-r', $end_tag,
		    $module_name);

    # Ideally, we should use IO::Select, but that is broken on Win32.
    # With CVS, read first from stdout.  If that is empty, then an
    # error has occurred, and that can be read from stderr.
    my $buf = "";
    while (read($read_stdout_fh, $buf, 16384)) {
	print $stdout_fh $buf;
    }
    while (read($read_stderr_fh, $buf, 16384)) {
	print $stderr_fh $buf;
    }

    # Wait for the process to terminate.
    waitpid($pid, 0);

    # Flush the output file handles.
    $stdout_fh->flush;
    $stderr_fh->flush;

    return $Codestriker::OK;
}

1;
