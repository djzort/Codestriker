###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Perforce repository class.

package Codestriker::Repository::Perforce;

use strict;

use Codestriker::Repository;
@Codestriker::Repository::Perforce::ISA = ("Codestriker::Repository");

# Constructor, which takes as a parameter the password, hostname and port.
sub new ($$$$$) {
    my ($type, $user, $password, $hostname, $port) = @_;

    my $repository_string = "perforce:${user}" .
      (defined $password && $password ne '' ? ":${password}" : '') .
        "@" . "${hostname}:${port}";
    my $self = Codestriker::Repository->new($repository_string);

    $self->{user} = $user;
    $self->{password} = $password;
    $self->{hostname} = $hostname;
    $self->{port} = $port;
    bless $self, $type;
}

# Setup the common P4 arguments.
sub _setup_base_p4_args {
    my $self = shift;

    my @args = ();
    push @args, '-p';
    push @args, $self->{hostname} . ':' . $self->{port};
    push @args, '-u';
    push @args, $self->{user};

    my $password = $self->{password};
    if (defined $password && $password ne '') {
        push @args, '-P';
        push @args, $password;
    }

    return @args;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Run the appropriate Perforce command.
    my $read_data = '';
    my $read_stdout_fh = new FileHandle;
    open($read_stdout_fh, '>', \$read_data);

    my @args = $self->_setup_base_p4_args();
    push @args, 'print';
    push @args, '-q';
    push @args, $filename . "#" . $revision;

    Codestriker::execute_command($read_stdout_fh, undef,
                                 $Codestriker::p4, @args);

    # Process the data for the topic.
    open($read_stdout_fh, '<', \$read_data);
    for (my $i = 1; <$read_stdout_fh>; $i++) {
        $_ = Codestriker::decode_topic_text($_);
        chop;
        $$content_array_ref[$i] = $_;
    }
}

# Retrieve the "root" of this repository.
sub getRoot ($) {
    my ($self) = @_;
    return $self->{repository_string};
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

    my @args = $self->_setup_base_p4_args();

    if ($module_name ne '' && $start_tag ne '' && $end_tag ne '' &&
        $start_tag ne $end_tag) {
        my $rev1 = "$module_name\@$start_tag";
        my $rev2 = "$module_name\@$end_tag";

        push @args, 'diff2';
        push @args, '-du';
        push @args, '-u';
        push @args, $rev1;
        push @args, $rev2;
    }
    else { # original case with just one tag specified.
        my $tag = $start_tag ne '' ? $start_tag : $end_tag;

        push @args, 'describe';
        push @args, 'du';
        push @args, $tag;
    }

    # Execute the command.
    Codestriker::execute_command($stdout_fh, $stderr_fh, $Codestriker::p4,
                                 @args);
    return $Codestriker::OK;
}

1;
