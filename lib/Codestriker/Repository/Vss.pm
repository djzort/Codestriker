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

# Switch for emitting debug information, which will output what VSS commands
# have executed.
my $_DEBUG = 1;

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
sub _wrap_vss_command {
    my ($self, $cmd) = @_;

    my $ssdir = $self->{ssdir};

    if (defined $ssdir) {
	my $perl_cmd = $cmd;
	$perl_cmd =~ s/\"/\\\"/g;
	$perl_cmd = "perl -e \"" .
	    (defined $ssdir ? "\$ENV{SSDIR}='$ssdir' ; " : "") .
	    "system('$perl_cmd')\"";
	print STDERR "Executing $perl_cmd\n" if $_DEBUG;
	flush STDERR if $_DEBUG;
	return $perl_cmd;
    }
    else {
	# No need to change the command, as SSDIR does not need to be set.
	print STDERR "Executing $cmd\n" if $_DEBUG;
	flush STDERR if $_DEBUG;
	return $cmd;
    }
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Create a temporary directory where all of the temporary files
    # will be written to.
    my $tempdir;
    if (defined $Codestriker::tmpdir && $Codestriker::tmpdir ne "") {
	$tempdir = tempdir(DIR => $Codestriker::tmpdir, CLEANUP => 1);
    }
    else {
	$tempdir = tempdir(CLEANUP => 1);
    }

    # Retrieve a read-only copy of the file into a temporary
    # directory.  Make sure the command output is put into
    # a temporary file, rather than stdout/stderr.
    my $varg = ($revision =~ /^\d+$/) ? "-V$revision" : "\"-VL$revision\"";
    my $command_output = "$tempdir\\___output.txt";
    my $cmd = "\"$Codestriker::vss\" get \"$filename\"" .
	" -y" . $self->{username} . "," . $self->{password} .
	" $varg -I-Y -O\"$command_output\" -GWR -GL\"$tempdir\"";
    system($self->_wrap_vss_command($cmd));

    $filename =~ /\/([^\/]+)$/o;
    my $basefilename = $1;
    if (open(VSS, "$tempdir/$basefilename")) {
	for (my $i = 1; <VSS>; $i++) {
	    chop;
	    $$content_array_ref[$i] = $_;
	}
	close VSS;
	unlink "$tempdir/$basefilename";
    }

    # Remove the temporary directory.
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
    }
    else {
	$tempdir = tempdir(CLEANUP => 1);
    }

    # Execute the VSS command to retrieve all of the entries in this label.
    # Note we can't set SSDIR in the environment, so we need to do that in
    # the command below.

    my $ssdir = $self->{ssdir};
    my $cmd = "\"$Codestriker::vss\" dir \"$module_name\"" .
	" -y" . $self->{username} . "," . $self->{password} .
	" -R \"-VL${tag}\" -I-Y";

    open(VSS, $self->_wrap_vss_command($cmd) . " |")
	|| die "Can't open connection to VSS repository: $!";

    # Collect the list of filename and revision numbers into a list.
    my @files = ();
    my @versions = ();
    my $current_dir = '';
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
	$cmd = "\"$Codestriker::vss\" properties \"$files[$i]\"" .
	    " -y" . $self->{username} . "," . $self->{password} .
	    " -I-Y";
	open(VSS, $self->_wrap_vss_command($cmd) . " |")
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
	    $cmd = "\"$Codestriker::vss\" diff \"$files[$i]\"" .
		   " -y" . $self->{username} . "," . $self->{password} .
		   " -I-Y -DU3000X5 \"-VL${start_tag}~L${end_tag}\"" .
		   " -O\"$command_output\"";
	    system($self->_wrap_vss_command($cmd));
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
	    $cmd = "\"$Codestriker::vss\" get \"$files[$i]\"" .
		   " -y" . $self->{username} . "," . $self->{password} .
		   " \"-VL${tag}\" -I-Y -O\"$command_output\" -GWR -GL\"$tempdir\"";
	    system($self->_wrap_vss_command($cmd));

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

    # Remove the temporary directory.
    rmdir $tempdir;

    return $Codestriker::OK;
}

1;
