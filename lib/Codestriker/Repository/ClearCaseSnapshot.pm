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
use File::Temp qw/ tempdir /;
use File::Spec;

# Constructor.
#   - snapshot_dir:  Absolute path to the location that you access the
#     files in the snapshot view from.  NOT the view storage directory.
sub new ($$) {
    my ($type, $snapshot_dir) = @_;

    my $self = {};
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
    my $tempdir = tempdir(); 
    my $tempfile = File::Spec->catfile($tempdir, "Temp_YouCanDeleteThis");
    my $errorfile = File::Spec->catfile($tempdir, "Error_YouCanDeleteThis");

    my $error_msg;

    # Call 'cleartool get' to load the element
    my $command = "\"$Codestriker::cleartool\" get " .
                  "-to \"$tempfile\" \"$full_element_name\" " .
                  "2> \"$errorfile\"";
    my $ret = system($command);

    eval {

        if ($ret != 0) {
            # If there was an error, the message will be in the error file.
            # Read in that file and store it in the "$error_msg" variable
            # so that we can return it to the caller.
            open ERRORFILE, "<$errorfile"
                || die "ClearTool returned an error, but Codestriker couldn't read from the error file.";
            my (@errorlines) = <ERRORFILE>;
            $error_msg = "Error from ClearTool: " . join(" ", @errorlines);
            close ERRORFILE;
        } else {
            # Operation was succesful.  Load the file into the given array.
            open CONTENTFILE, "<$tempfile"
                || die "ClearTool execution succeeded, but Codestriker couldn't read from the output file.";
            for (my $i = 1; <CONTENTFILE>; $i++) {
                chop;
                $$content_array_ref[$i] = $_;
            }
            close CONTENTFILE;
        }

    };

    # See if anything called 'die' in the 'eval' block.
    if ($@) {
        $error_msg = $@;
    }

    if (defined($tempdir)) {
        unlink $errorfile;
        unlink $tempfile;
        rmdir $tempdir;
    }

    # If there was no error, this will be undefined
    return $error_msg
}

# Retrieve the "root" of this repository.
sub getRoot ($) {
    my ($self) = @_;
    return $self->{snapshot_dir};
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
    return "clearcase:" . $self->{snapshot_dir};
}

# Given a start tag, end tag and a module name, store the text into
# the specified file handle.  If the size of the diff goes beyond the
# limit, then return the appropriate error code.
sub getDiff ($$$$$$) {
    my ($self, $start_tag, $end_tag, $module_name, $fh, $stderr_fh) = @_;

    return $Codestriker::UNSUPPORTED_OPERATION;
}

1;
