###############################################################################
# Codestriker: Copyright (c) 2001 - 2004 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# CVS repository class which handles both local and pserver access methods.

package Codestriker::Repository::Cvs;

use strict;
use FileHandle;
use IPC::Open3;

# Factory method for creating a local CVS repository object.
sub build_local {
    my ($type, $cvsroot, $optional_prefix) = @_;

    my $self = {};
    $self->{cvsroot} = $cvsroot;
    $self->{optional_prefix} =
	defined $optional_prefix ? $optional_prefix : "";
    $self->{url} = "${optional_prefix}${cvsroot}";
    bless $self, $type;
}

# Factory method for creating a pserver CVS repository object.
sub build_pserver {
    my ($type, $optional_args, $username, $password, $hostname, $cvsroot) = @_;

    my $self = {};
    $self->{optional_args} = defined $optional_args ? $optional_args : "";
    $self->{username} = $username;
    $self->{password} = $password;
    $self->{hostname} = $hostname;
    $self->{cvsroot} = $cvsroot;
    $self->{url} = ":pserver${optional_args}:${username}:${password}\@" .
	"${hostname}:${cvsroot}";
    bless $self, $type;
}

# Factory method for creating a ext CVS repository object.
sub build_ext {
    my ($type, $optional_args, $username, $hostname, $cvsroot) = @_;

    my $self = {};
    $self->{optional_args} = defined $optional_args ? $optional_args : "";
    $self->{username} = $username;
    $self->{hostname} = $hostname;
    $self->{cvsroot} = $cvsroot;
    $self->{url} = ":ext${optional_args}:${username}\@${hostname}:${cvsroot}";
    bless $self, $type;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Open a pipe to the CVS repository.
    $ENV{'CVS_RSH'} = $Codestriker::ssh if defined $Codestriker::ssh;
    open(CVS, "\"$Codestriker::cvs\" -q -d \"" . $self->{url} .
	 "\" co -p -r $revision \"$filename\" |")
	|| die "Can't open connection to pserver CVS repository: $!";

    # Read the data.
    for (my $i = 1; <CVS>; $i++) {
	$_ = Codestriker::decode_topic_text($_);
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
sub getDiff ($$$$$$) {
    my ($self, $start_tag, $end_tag, $module_name,
	$stdout_fh, $stderr_fh, $default_to_head) = @_;

    # If $end_tag is empty, but the $start_tag has a value, or
    # $start_tag is empty, but $end_tag has a value, simply 
    # retrieve the diff that corresponds to the files full
    # contents corresponding to that tag value.
    if ($start_tag eq "" && $end_tag ne "") {
	$start_tag = "1.0";
    } elsif ($start_tag ne "" && $end_tag eq "") {
	$end_tag = $start_tag;
	$start_tag = "1.0";
    }

    # Cheat - having two '-u's changes nothing.
    my $extra_options = $default_to_head ? '-u' : '-f';

    my $write_stdin_fh = new FileHandle;
    my $read_stdout_fh = new FileHandle;
    my $read_stderr_fh = new FileHandle;
    $ENV{'CVS_RSH'} = $Codestriker::ssh if defined $Codestriker::ssh;
    my $pid = open3($write_stdin_fh, $read_stdout_fh, $read_stderr_fh,
		    $Codestriker::cvs, '-q', '-d', $self->{url},
		    'rdiff', '-u', $extra_options,
		    '-r', $start_tag, '-r', $end_tag, $module_name);

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
