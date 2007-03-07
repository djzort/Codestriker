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
    my ($type, $repository_url, $user, $password) = @_;

    # Determine if there are additional parameters required for user
    # authentication.
    my @userCmdLine = ();
    if (defined($user) && defined($password)) {
        push @userCmdLine, '--username';
	push @userCmdLine, $user;
	push @userCmdLine, '--password';
	push @userCmdLine, $password;
    }

    # Make sure the repo url does not end in a /, the 
    # rest of the module assumes that it does not.
    $repository_url =~ s/[\\\/]^//;
    
    # Replace any spaces with %20 uri friendly escapes.
    $repository_url =~ s/ /%20/g;

    my $self = {};
    $self->{repository_url} = $repository_url;
    $self->{userCmdLine} = \@userCmdLine;

    bless $self, $type;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Replace any spaces with %20 uri friendly escapes.
    $filename =~ s/ /%20/g;

    my $write_stdin_fh = new FileHandle;
    my $read_stdout_fh = new FileHandle;
    my $read_stderr_fh = new FileHandle;

    my @args = ();
    push @args, 'cat';
    push @args, '--non-interactive';
    push @args, '--no-auth-cache';
    push @args, @{ $self->{userCmdLine} };
    push @args, '--revision';
    push @args, $revision;
    push @args, $self->{repository_url} . '/' . $filename;
    
    my $pid = open3($write_stdin_fh, $read_stdout_fh, $read_stderr_fh,
		    $Codestriker::svn, @args);

    # Read the data.
    for (my $i = 1; <$read_stdout_fh>; $i++) {
	$_ = Codestriker::decode_topic_text($_);
	chop;
	$$content_array_ref[$i] = $_;
    }

    # Log anything on standard error to apache error log.
    my $buf;
    my $first_lines = 1;
    while (read($read_stderr_fh, $buf, 16384)) {
        print STDERR "$Codestriker::svn " .
	    (join @args, ' ') . "\n" if $first_lines;
        $first_lines = 0;
	print STDERR $buf;
     }
      
    waitpid($pid, 0);
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

    # Make sure the module does not end or start with a /
    $module_name =~ s/\/$//;
    $module_name =~ s/^\///;

    # Replace any spaces with %20 uri friendly escapes.
    my $filename = $module_name;
    $filename =~ s/ /%20/g;

    my $write_stdin_fh = new FileHandle;
    my $read_stdout_fh = new FileHandle;
    my $read_stderr_fh = new FileHandle;

    my @args = ();
    push @args, 'cat';
    push @args, '--non-interactive';
    push @args, '--no-auth-cache';
    push @args, @{ $self->{userCmdLine} };
    push @args, '--revision';
    push @args, 'HEAD';
    push @args, $self->{repository_url} . '/' . $filename;

    my $pid = open3($write_stdin_fh, $read_stdout_fh, $read_stderr_fh,
		    $Codestriker::svn, @args);

    while(<$read_stdout_fh>) {}

    my $directory;

    # If there is an error about it being a directory, then use the
    # module name as a directory.
    while(<$read_stderr_fh>) {
        my $line = $_;

        if ($line =~ /^svn:.*URL '.*' refers to a directory/) {
            $directory = $module_name;
        }
    }

    # if there was no error, then the module name is a file, so get the
    # directory before the file name.
    if (! defined $directory) {
        $module_name =~ /(.*)\/[^\/]+/;
        $directory = $1;
    }

    $write_stdin_fh->close();
    $read_stdout_fh->close();
    $read_stderr_fh->close();

    $write_stdin_fh = new FileHandle;
    $read_stdout_fh = new FileHandle;
    $read_stderr_fh = new FileHandle;

    @args = ();
    push @args, 'diff';
    push @args, '--non-interactive';
    push @args, '--no-auth-cache';
    push @args, @{ $self->{userCmdLine} };
    push @args, '-r';
    push @args, $start_tag . ':' . $end_tag;
    push @args, '--old';
    push @args, $self->{repository_url};
    push @args, $module_name;

    $pid = open3($write_stdin_fh, $read_stdout_fh, $read_stderr_fh,
		 $Codestriker::svn, @args);

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

                $line =~ s/^--- /--- $directory\// or
                $line =~ s/^Index: /Index: $directory\// or
                $line =~ s/^\+\+\+ /\+\+\+ $directory\//;
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
