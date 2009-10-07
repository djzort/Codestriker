###############################################################################
# Codestriker: Copyright (c) 2004 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Handler for ClearCase Snapshot Views.
# Contributed by "Kannan Goundan" <kannan@letterboxes.org>.

package Codestriker::Repository::ClearCaseSnapshot;

use strict;
use Fatal qw / open close /;
use File::Temp qw/ tempdir /;
use File::Spec;

use Codestriker::Repository;
@Codestriker::Repository::ClearCaseSnapshot::ISA = ("Codestriker::Repository");

# Constructor.
#   - snapshot_dir:  Absolute path to the location that you access the
#     files in the snapshot view from.  NOT the view storage directory.
sub new ($$) {
    my ($type, $snapshot_dir) = @_;

    my $self = Codestriker::Repository->new("clearcase:$snapshot_dir");
    $self->{snapshot_dir} = $snapshot_dir;
    bless $self, $type;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # full_element_name = {snapshot_dir}/{filename}@@{revision}
    my $full_element_name = File::Spec->catfile($self->{snapshot_dir},
                                                $filename);
    if (defined($revision) && length($revision) > 0) {
        $full_element_name = $full_element_name . '@@' . $revision;
    }

    # Create a temporary directory to store the results of 'cleartool get'.
    my $tempdir;
    if (defined $Codestriker::tmpdir && $Codestriker::tmpdir ne "") {
        $tempdir = tempdir(DIR => $Codestriker::tmpdir, CLEANUP => 1);
    } else {
        $tempdir = tempdir(CLEANUP => 1);
    }

    my $tempfile = File::Spec->catfile($tempdir, "Temp_YouCanDeleteThis");
    my $errorfile = File::Spec->catfile($tempdir, "Error_YouCanDeleteThis");

    my @ctArgs;
    push @ctArgs, 'get';
    push @ctArgs, '-to';
    push @ctArgs, $tempfile;
    push @ctArgs, $full_element_name;
    Codestriker::execute_command(\*STDERR, \*STDERR, $Codestriker::cleartool, @ctArgs);

    eval {
        open (CONTENTFILE, "<$tempfile");
        for (my $i = 1; <CONTENTFILE>; $i++) {
            $_ = Codestriker::decode_topic_text($_);
            chop;
            $$content_array_ref[$i] = $_;
        }
        close CONTENTFILE;
    };

    if (defined($tempdir)) {
        unlink $errorfile;
        unlink $tempfile;
        rmdir $tempdir;
    }

    if ($@) {
        croak "Unable to get Clearcase file: $full_element_name: $@\n";
    }
}

# Retrieve the "root" of this repository.
sub getRoot ($) {
    my ($self) = @_;
    return $self->{snapshot_dir};
}

# Given a start tag, end tag and a module name, store the text into
# the specified file handle.  If the size of the diff goes beyond the
# limit, then return the appropriate error code.
sub getDiff ($$$$$$) {
    my ($self, $start_tag, $end_tag, $module_name, $fh, $stderr_fh) = @_;

    return $Codestriker::UNSUPPORTED_OPERATION;
}

1;
