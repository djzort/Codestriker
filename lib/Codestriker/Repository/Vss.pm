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
use File::Temp qw/ tempdir /;

# Constructor, which takes as a parameter the repository url.  At the moment,
# this url is ignored, and is assumed to be localhost.
sub new ($$) {
    my ($type, $repository_url) = @_;

    my $self = {};
    $self->{repository_url} = $repository_url;
    bless $self, $type;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # This not safe under Apache2 with threads, but this will do for now.
    # Record the current directory, make a temporary directory, issue the
    # vss command, read the file, remove the directory then continue.
    my $saved_cwd = cwd();
    my $tempdir = tempdir();
    chdir $tempdir || die "Failed to change to directory: \"$tempdir\": $!";
    
    my $error_file = "__________error_file.txt";
    system("\"$Codestriker::vss\" get \"\$\/$filename\" -V$revision " .
	   "\"-O&${error_file}\"");

    # Now read the data from the file.  Need to get the basename of the file.
    $filename =~ /\/([^\/]+)$/o;
    my $basename = $1;
    open(VSS, $basename) || die "Unable to open file \"$basename\": $!";
    for (my $i = 1; <VSS>; $i++) {
	chop;
	$$content_array_ref[$i] = $_;
    }
    close VSS;

    # Delete the two files, and the temporary directory, then chdir back to
    # where we were.
    unlink $error_file;
    unlink $basename;

    # Avoid tainting issues.
    $saved_cwd =~ /^(.*)$/;
    chdir $1;
    rmdir $tempdir;
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
    return "vss:" . $self->getRoot();
}

# The getDiff operation is not supported.
sub getDiff ($$$$$) {
    my ($self, $start_tag, $end_tag, $module_name, $fh, $error_fh) = @_;

    return $Codestriker::UNSUPPORTED_OPERATION;
}

1;
