#!c:/perl/bin/perl.exe -w

###############################################################################
# Codestriker: Copyright (c) 2001 - 2004 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Perl script for creating a single diff file over a Visual SourceSafe
# project, in a suitable form that can be input as a Codestiker
# (http://codestriker.sourceforge.net) topic.

###############################################################################
# Script configuration.

# If no argument is passed to the script, this is the SourceSafe
# project which will be used.  Modify this to reflect your own usage.
my $ss_project = '$/Project';

# Set this to the path of your ss.exe executable.
my $ss = 'C:/Program Files/Microsoft Visual Studio/VSS/win32/ss.exe';

# Specify the SS username and password to use when running ss.exe
# commands.
my $ss_username = 'admin';
my $ss_password = 'password';

# End script configuration.
###############################################################################

use strict;
use File::Temp qw/ tmpnam tempdir /;

# First, check if an argument has been passed, which overrides
# $ss_project.
if ($#ARGV == 0) {
    $ss_project = $ARGV[0];
} elsif ($#ARGV > 0) {
    print STDERR "usage: ssdiff.pl [SourceSafe Project] > file.txt\n";
    print STDERR "       SourceSafe Project defaulted to $ss_project\n";
    exit 1;
}

# Create a temporary directory where all of the temporary files
# will be written to.  This iwll be automatically removed when the
# script exits.
my $tempdir;
if (defined $Codestriker::tmpdir && $Codestriker::tmpdir ne "") {
    $tempdir = tempdir(DIR => $Codestriker::tmpdir, CLEANUP => 1);
}
else {
    $tempdir = tempdir(CLEANUP => 1);
}

# Now execute an 'ss dir' command to determine what files are a part
# of this project.
open(VSS, "\"$ss\" dir \"$ss_project\" -y${ss_username},{$ss_password}" .
     " -R -I- |") || die "Unable to run ss diff command: $!";

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

# Now for each text file, we need to run an 'ss diff' command to see
# what contents have changed.  It is assumed that the user has run this
# command from a checkedout area that matches the $ss_project parameter.
for (my $i = 0; $i <= $#files; $i++) {
    # Determine if the file is a text file, and if not, skip it.
    open(VSS, "\"$ss\" properties \"$files[$i]\"" .
	 " -y${ss_username},${ss_password} -I- |")
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

    # Now need to construct the path to the real file from the SS path.
    # First we need to remove the project part from the full "path".
    $files[$i] =~ /$ss_project\/(.*)$/;
    my $real_file = $1;
    if (! defined $real_file) {
	die "Can't extract filename from $files[$i] for project $ss_project\n";
    }

    # Translate the forward slashes to back slashes.
    $real_file =~ s/\//\\/g;

    print STDERR "Diffing $real_file against $files[$i]\n";

    # Note the command has to be redirected to a file, otherwise the ss
    # command will wrap the lines.
    my $command_output = "$tempdir\\___output.txt";
    system("\"$ss\" diff -y${ss_username},${ss_password} -I-" .
	   " -DU3000 -O\"$command_output\" \"$files[$i]\" \"$real_file\"");
    if (open(VSS, $command_output)) {
	# Because ss doesn't include the version number of the file we are
	# diffing against, we have to do so here.
	my $first_line = <VSS>;
	chop $first_line;
	print STDOUT "$first_line;$versions[$i]\n";
	while (<VSS>) {
	    print STDOUT $_;
	}
	close VSS;
    }
}


