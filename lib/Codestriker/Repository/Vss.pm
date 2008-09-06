###############################################################################
# Codestriker: Copyright (c) 2001,2002,2003 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# VSS repository access package.

package Codestriker::Repository::Vss;

use strict;
use Cwd;
use File::Temp qw/ tmpnam tempdir /;
use IO::Handle;

# Switch for emitting debug information.
my $_DEBUG = 0;

# Constructor, which takes the username and password as parameters.
sub new {
    my ($type, $username, $password, $ssdir) = @_;

    my $self = {};
    $self->{username} = $username;
    $self->{password} = $password;
    $self->{ssdir} = $ssdir;
    bless $self, $type;
}

# Method for wrapping the VSS command if necessary via a perl
# invocation so that the SSDIR environment variable is set pointing to
# the correct VSS repository.  We can't do this with $ENV since
# apache2 doesn't allow us to do this.  We assume perl is in the
# PATH.
sub _write_vss_command {
    my ($self, $cmd, $tmpfile) = @_;

    my $ssdir = $self->{ssdir};

    open (TMPFILE, ">$tmpfile") || die "Can't open $tmpfile: $!";
    print TMPFILE "\@echo off\n";
    print STDERR "\@echo off\n" if $_DEBUG;
    print TMPFILE "set SSDIR=$ssdir\n" if defined $ssdir;
    print STDERR "set SSDIR=$ssdir\n" if defined $ssdir && $_DEBUG;
    print TMPFILE "$cmd\n";
    print STDERR "$cmd\n" if $_DEBUG;
    close TMPFILE;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # VSS command to use.
    my $vss = $Codestriker::vss;
    $vss =~ s/\//\\/g;

    # Create a temporary directory where all of the temporary files
    # will be written to.
    my $tempdir;
    if (defined $Codestriker::tmpdir && $Codestriker::tmpdir ne "") {
        $tempdir = tempdir(DIR => $Codestriker::tmpdir, CLEANUP => 1);
    } else {
        $tempdir = tempdir(CLEANUP => 1);

        # Hack alert for windows - temporary directory needs to start
        # with a letter, or commands below will fail.  Most people will
        # set the temporary directory explicitly in the conf file.
        $tempdir = 'C:' . $tempdir if $tempdir =~ /^[\\\/]/o;
    }

    # Temporary Batch file for executing VSS commands.
    my $tmp_batch_file = "$tempdir/tmp.bat";

    # Retrieve a read-only copy of the file into a temporary
    # directory.  Make sure the command output is put into
    # a temporary file, rather than stdout/stderr.
    my $varg = ($revision =~ /^\d+$/) ? "-V$revision" : "\"-VL$revision\"";
    my $command_output = "$tempdir\\___output.txt";
    my $cmd = "\"$vss\" get \"$filename\"" .
      " -y" . $self->{username} . "," . $self->{password} .
        " $varg -I-Y -O\"$command_output\" -GWR -GL\"$tempdir\"";
    $self->_write_vss_command($cmd, $tmp_batch_file);
    system("\"$tmp_batch_file\"");

    $filename =~ /\/([^\/]+)$/o;
    my $basefilename = $1;
    if (open(VSS, "$tempdir/$basefilename")) {
        for (my $i = 1; <VSS>; $i++) {
            $_ = Codestriker::decode_topic_text($_);
            chop;
            $$content_array_ref[$i] = $_;
        }
        close VSS;
        unlink "$tempdir/$basefilename";
    }

    # Remove the temporary directory and batch file.
    unlink $tmp_batch_file;
    rmdir $tempdir;
}

# Retrieve the "root" of this repository.
sub getRoot ($) {
    my ($self) = @_;
    return "vss:";
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
    return "vss:" . $self->{username} . ":" . $self->{password};
}

# Retrieve the specified VSS diff directly using VSS commands.
sub getDiff ($$$$$) {
    my ($self, $start_tag, $end_tag, $module_name, $fh, $error_fh) = @_;

    # VSS command to use.
    my $vss = $Codestriker::vss;
    $vss =~ s/\//\\/g;

    # Currently we only support either start_tag or end_tag being set.
    my $tag = '';
    $tag = $start_tag if $start_tag ne '' && $end_tag eq '';
    $tag = $end_tag if $start_tag eq '' && $end_tag ne '';
    $tag = $end_tag if $start_tag ne '' && $end_tag ne '';
    return $Codestriker::UNSUPPORTED_OPERATION if $tag eq '';

    # Create a temporary directory where all of the temporary files
    # will be written to.
    my $tempdir;
    if (defined $Codestriker::tmpdir && $Codestriker::tmpdir ne "") {
        $tempdir = tempdir(DIR => $Codestriker::tmpdir, CLEANUP => 1);
    } else {
        $tempdir = tempdir(CLEANUP => 1);

        # Hack alert for windows - temporary directory needs to start
        # with a letter, or commands below will fail.  Most people will
        # set the temporary directory explicitly in the conf file.
        $tempdir = 'C:' . $tempdir if $tempdir =~ /^[\\\/]/o;
    }

    # Temporary Batch file for executing VSS commands.
    my $tmp_batch_file = "$tempdir/tmp.bat";

    # Execute the VSS command to retrieve all of the entries in this label.
    # Note we can't set SSDIR in the environment, so we need to do that in
    # the command below.

    my $ssdir = $self->{ssdir};
    my $varg = ($tag =~ /^\d+$/) ? "-V$tag" : "\"-VL$tag\"";
    my $cmd = "\"$vss\" dir \"$module_name\"" .
      " -y" . $self->{username} . "," . $self->{password} .
        " -R $varg -I-Y";
    $self->_write_vss_command($cmd, $tmp_batch_file);

    open(VSS, "\"$tmp_batch_file\" |")
      || die "Can't open connection to VSS repository: $!";

    # Collect the list of filename and revision numbers into a list.
    my @files = ();
    my @versions = ();

    # Initialise this in case module just refers to a single file.
    my $current_dir = '';
    if ($module_name =~ /^(.*)\/[^\/]+$/o) {
        $current_dir = $1;
    }

    while (<VSS>) {
        if (/^(\$\/.*):$/o) {
            # Entering a new top-level directory.
            $current_dir = $1;
        } elsif (/^\$[^\/]/o) {
            # Sub-directory entry which can be skipped.
        } elsif (/^\d+ item/o) {
            # Item count line which can be skipped.
        } elsif (/^\s*$/o) {
            # Skip blank lines.
        } elsif (/^(.*);(\d+)$/o) {
            # Actual file entry with version number.
            push @files, "$current_dir/$1";
            push @versions, $2;
        }
    }
    close VSS;

    # Now for each file, we need to retrieve the actual contents and output
    # it into a diff file.  First, create a temporary directory to store the
    # files.
    for (my $i = 0; $i <= $#files; $i++) {
        # Determine if the file is a text file, and if not, skip it.
        $cmd = "\"$vss\" properties \"$files[$i]\"" .
          " -y" . $self->{username} . "," . $self->{password} .
            " -I-Y";
        $self->_write_vss_command($cmd, $tmp_batch_file);
        open(VSS, "\"$tmp_batch_file\" |")
          || die "Unable to run ss properties on $files[$i]\n";
        my $text_type = 0;
        while (<VSS>) {
            if (/Type:\s*Text/o) {
                $text_type = 1;
                last;
            }
        }
        close(VSS);
        next if $text_type == 0;

        my $command_output = "$tempdir\\___output.txt";
        if ($start_tag ne '' && $end_tag ne '') {
            my $varg = "\"";
            $varg .= ($start_tag =~ /^\d+$/) ? "-V${start_tag}~" : "-VL${start_tag}~";
            $varg .= ($end_tag =~ /^\d+$/) ? $end_tag : "L${end_tag}";
            $varg .= "\"";
            $cmd = "\"$vss\" diff \"$files[$i]\"" .
              " -y" . $self->{username} . "," . $self->{password} .
                " -I-Y -DU3000X5 $varg" .
                  " -O\"$command_output\"";
            $self->_write_vss_command($cmd, $tmp_batch_file);
            system("\"$tmp_batch_file\"");
            if (open(VSS, $command_output)) {
                while (<VSS>) {
                    print $fh $_;
                }
                close VSS;
            }
        } else {
            # Retrieve a read-only copy of the file into a temporary
            # directory.  Make sure the command output is put into
            # a temporary file, rather than stdout/stderr.
            my $varg = ($tag =~ /^\d+$/) ? "-V$tag" : "\"-VL$tag\"";
            $cmd = "\"$vss\" get \"$files[$i]\"" .
              " -y" . $self->{username} . "," . $self->{password} .
                " $varg -I-Y -O\"$command_output\" -GWR -GL\"$tempdir\"";
            $self->_write_vss_command($cmd, $tmp_batch_file);
            system("\"$tmp_batch_file\"");

            $files[$i] =~ /\/([^\/]+)$/o;
            my $basefilename = $1;
            my @data = ();
            if (open(VSS, "$tempdir/$basefilename")) {
                while (<VSS>) {
                    push @data, $_;
                }
                close VSS;
                unlink "$tempdir/$basefilename";
            }
            my $data_size = $#data + 1;

            # Output the file header information in VSS diff format.
            print $fh "Diffing: $files[$i];$versions[$i]\n";
            print $fh "Against: \n\n";
            print $fh "0a1,$data_size\n";
            for (my $index = 0; $index <= $#data; $index++) {
                print $fh "> " . $data[$index];
            }
        }
        unlink $command_output;
        print $fh "\n";
    }

    # Remove the temporary directory and temporary batch file.
    unlink $tmp_batch_file;
    rmdir $tempdir;

    return $Codestriker::OK;
}

1;
