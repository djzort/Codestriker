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
use Fatal qw / open close /;

# Factory method for creating a local CVS repository object.
sub build_local {
    my ($type, $cvsroot, $optional_prefix) = @_;

    my $self = {};
    $self->{cvsroot} = $cvsroot;
    $optional_prefix = "" unless defined $optional_prefix;
    $self->{optional_prefix} = $optional_prefix;
    $self->{url} = "${optional_prefix}${cvsroot}";
    bless $self, $type;
}

# Factory method for creating a pserver CVS repository object.
sub build_pserver {
    my ($type, $optional_args, $username, $password, $hostname, $cvsroot) = @_;

    my $self = {};
    $optional_args = "" unless defined $optional_args;
    $self->{optional_args} = $optional_args;
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
    $optional_args = "" unless defined $optional_args;
    $self->{optional_args} = $optional_args;
    $self->{username} = $username;
    $self->{hostname} = $hostname;
    $self->{cvsroot} = $cvsroot;
    $self->{url} = ":ext${optional_args}:${username}\@${hostname}:${cvsroot}";
    bless $self, $type;
}

# Factory method for creating an SSPI CVS repository object.
sub build_sspi {
    my ($type, $username, $password, $hostname, $cvsroot) = @_;

    my $self = {};
    $self->{optional_args} = "";
    $self->{username} = $username;
    $self->{hostname} = $hostname;
    $self->{cvsroot} = $cvsroot;
    $self->{url} = ":sspi:${username}:${password}\@${hostname}:${cvsroot}";
    bless $self, $type;
}


# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Open a pipe to the CVS repository.
    $ENV{'CVS_RSH'} = $Codestriker::ssh if defined $Codestriker::ssh;

    my $read_data = '';
    my $read_stdout_fh = new FileHandle;
    open($read_stdout_fh, '>', \$read_data);
    my @args = ();
    push @args, '-q';
    push @args, '-d';
    push @args, $self->{url};
    push @args, 'co';
    push @args, '-p';
    push @args, '-r';
    push @args, $revision;
    push @args, $filename;
    Codestriker::execute_command($read_stdout_fh, undef,
                                 $Codestriker::cvs, @args);

    # Process the data for the topic.
    open($read_stdout_fh, '<', \$read_data);
    for (my $i = 1; <$read_stdout_fh>; $i++) {
        $_ = Codestriker::decode_topic_text($_);
        chop;
        $$content_array_ref[$i] = $_;
    }
    close $read_stdout_fh;
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
    my $extra_options = $default_to_head ? '-f' : '-u';

    $ENV{'CVS_RSH'} = $Codestriker::ssh if defined $Codestriker::ssh;

    Codestriker::execute_command($stdout_fh, $stderr_fh, $Codestriker::cvs,
                                 '-q', '-d', $self->{url}, 'rdiff',
                                 $extra_options, '-u', '-r', $start_tag,
                                 '-r', $end_tag, $module_name);
    return $Codestriker::OK;
}

1;
