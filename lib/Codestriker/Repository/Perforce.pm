###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Perforce repository class.

package Codestriker::Repository::Perforce;

use strict;

# Constructor, which takes as a parameter the password, hostname and port.
sub new ($$$$$) {
    my ($type, $user, $password, $hostname, $port) = @_;

    my $self = {};
    $self->{user} = $user;
    $self->{password} = $password;
    $self->{hostname} = $hostname;
    $self->{port} = $port;
    $self->{root} = "perforce:${user}" .
      (defined $password && $password ne '' ? ":${password}" : '') .
        "@" . "${hostname}:${port}";
    bless $self, $type;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Open a pipe to the local CVS repository.
    my $password = $self->{password};
    open(P4, "\"$Codestriker::p4\"" .
         " -p " . $self->{hostname} . ':' . $self->{port} .
         " -u " . $self->{user} .
         (defined $password && $password ne '' ?
          " -P " . $self->{password} : '') .
         " print -q \"$filename\"" . "#" . "$revision |")
      || die "Can't retrieve data using p4: $!";

    # Read the data.
    for (my $i = 1; <P4>; $i++) {
        $_ = Codestriker::decode_topic_text($_);
        chop;
        $$content_array_ref[$i] = $_;
    }
    close P4;
}

# Retrieve the "root" of this repository.
sub getRoot ($) {
    my ($self) = @_;
    return $self->{root};
}

# Return a URL which views the specified file and revision.
sub getViewUrl ($$$) {
    my ($self, $filename, $revision) = @_;

    # Lookup the file viewer from the configuration.
    my $viewer = $Codestriker::file_viewer->{$self->{root}};
    return (defined $viewer) ? $viewer . "/" . $filename : "";
}

# Return a string representation of this repository.
sub toString ($) {
    my ($self) = @_;
    return $self->{root};
}

# Given a start tag, end tag and a module name, store the text into
# the specified file handle.  If the size of the diff goes beyond the
# limit, then return the appropriate error code.
sub getDiff ($$$$$) {
    my ($self, $start_tag, $end_tag, $module_name,
        $stdout_fh, $stderr_fh) = @_;

    # Currently diff retrievals are only supported for a single tag.
    if ($start_tag ne '' && $end_tag ne '') {
        print $stderr_fh, "Diff retrieval cannot be performed with both tags defined.\n";
        return $Codestriker::OK;
    }
    my $tag = $start_tag ne '' ? $start_tag : $end_tag;

    Codestriker::execute_command($stdout_fh, $stderr_fh, $Codestriker::p4,
                                 '-p', $self->{hostname} . ':' . $self->{port},
                                 '-u', $self->{user},
                                 '-P', $self->{password}, 'describe',
                                 '-du', $tag);
    return $Codestriker::OK;
}

1;
