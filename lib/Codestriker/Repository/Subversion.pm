###############################################################################
# Codestriker: Copyright (c) 2001,2002,2003 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Subversion repository access package.

package Codestriker::Repository::Subversion;
use IPC::Open3;

use strict;

# Constructor, which takes as a parameter the repository url.
sub new ($$) {
    my ($type, $repository_url) = @_;

    my $self = {};
    $self->{repository_url} = $repository_url;
    bless $self, $type;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Open a pipe to the local Subversion repository.
    open(SVN, "svn cat --revision $revision \"" . $self->{repository_url} .
	 "/$filename\" 2>/dev/null |")
	|| die "Can't retrieve information from Subversion repository: $!";

    # Read the data.
    for (my $i = 1; <SVN>; $i++) {
	chop;
	$$content_array_ref[$i] = $_;
    }
    close SVN;
}

# Retrieve the "root" of this repository.
sub getRoot ($) {
    my ($self) = @_;
    return $self->{repository_url};
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
    return "svn:" . $self->getRoot();
}

# The getDiff operation, pull out a change set based on the start and end 
# revision number, confined to the specified moduled_name.
sub getDiff ($$$$$) {
    my ($self, $start_tag, $end_tag, $module_name, $stdout_fh, $stderr_fh) = @_;

    my $cmd = "svn diff --non-interactive -r $start_tag:$end_tag " . 
              "--old \"$self->{repository_url}\" \"$module_name\"";

    my $write_stdin_fh = new FileHandle;
    my $read_stdout_fh = new FileHandle;
    my $read_stderr_fh = new FileHandle;

    my $pid = open3($write_stdin_fh, $read_stdout_fh, $read_stderr_fh,$cmd);

    # Make sure the module does not end or start with a / 
    $module_name =~ s/\\$//;
    $module_name =~ s/^\\//;

    while(<$read_stdout_fh>) {
        my $line = $_;

        # If the user specifies a path (a branch in Subversion), the
        # diff file does not come back with a path rooted from the
        # repository base making it impossible to pull the entire file
        # back out. This code attempts to change the diff file on the
        # fly to ensure that the full path is present. This is a bug
        # against Subversion, so eventually it will be fixed, so this
        # code can't break when the diff command starts returning the
        # full path.
        if ($line =~ /^--- / || $line =~ /^\+\+\+ / || $line =~ /^Index: /) {
            # Check if the bug has been fixed.
            if ($line =~ /^\+\+\+ $module_name/ == 0 && 
                $line =~ /^--- $module_name/ == 0 &&
                $line =~ /^Index: $module_name/ == 0) {

                $line =~ s/^--- /--- $module_name\// or
                $line =~ s/^Index: /Index: $module_name\// or
                $line =~ s/^\+\+\+ /\+\+\+ $module_name\//;
            }
        }

        print $stdout_fh $line;
    }

    my $buf;
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
