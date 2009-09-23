###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Git repository class

package Codestriker::Repository::Git;

use strict;
use FileHandle;
use Fatal qw / open close / ;

use Codestriker::Repository;
@Codestriker::Repository::Git::ISA = ("Codestriker::Repository");

sub new_local ($$$) {
    my ($type, $path, $is_bare) = @_;

    my $self = Codestriker::Repository->new(":git:${path}");

    #$self->{gitdir} = $path . (defined $is_bare ? '' : '/.git');
    $self->{gitdir} = $path . "/.git";

    bless $self, $type;
}

# We could also support gitweb? ssh access?

sub retrieve ($$$\$) {
    my ($self, $filename, $blob_hash, $filedata_ref) = @_;
    # Command: git show <commit>:<file>
    my $read_data = '';
    my $read_stdout_fh = new FileHandle;
    open($read_stdout_fh, '>', \$read_data);
    Codestriker::execute_command($read_stdout_fh, undef, $Codestriker::git,
                                 '--git-dir=' . $self->{gitdir}, 'show',
                                 $blob_hash);

    # Process the data for the topic.
    open($read_stdout_fh, '<', \$read_data);
    for (my $i = 1; <$read_stdout_fh>; $i++) {
        $_ = Codestriker::decode_topic_text($_);
        chop;
        $$filedata_ref[$i] = $_;
    }
    close $read_stdout_fh;
}

sub getDiff ($$$$$$) {
    my ($self, $start_commit, $end_commit, $path,
        $stdout_fh, $stderr_fh, $default_to_head) = @_;
    # Command: git diff -U6 <start> <end>

    # Default end_commit to HEAD
    if ($end_commit eq "") {
        $end_commit = "HEAD";
    }

    # Default start_commit to parent of end_commit
    # Note: if end_commit is a merge, this is the first parent
    if ($start_commit eq "") {
        $start_commit = $end_commit . "^"
    }

    my @args = ();
    push @args, '--git-dir=' . "$self->{gitdir}";
    push @args, 'diff';
    # Get 6 lines of context
    push @args, '-U6';
    # Header will use full SHA1 in 'index <blob>..<blob>' line
    push @args, '--full-index';
    # Header will say diff --git $start_commit/<file> $end_commit/<file>
    push @args, "--src-prefix=" . $start_commit . "/";
    push @args, "--dst-prefix=" . $end_commit . "/";
    push @args, "$start_commit";
    push @args, "$end_commit";
    push @args, '--';
    if ($path ne ".") {
        push @args, "$path";
    }

    Codestriker::execute_command($stdout_fh, $stderr_fh, $Codestriker::git, @args);

    return $Codestriker::OK;
}

sub getRoot ($) {
    my ($self) = @_;
    return $self->{gitdir}
}

1;
