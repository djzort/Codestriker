###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# CVS repository class with access to a local repository.

package Codestriker::Repository::CvsLocal;

use strict;

# Constructor, which takes as a parameter the CVSROOT.
sub new ($$) {
    my ($type, $cvsroot) = @_;

    my $self = {};
    $self->{cvsroot} = $cvsroot;
    bless $self, $type;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Open a pipe to the local CVS repository.
    open(CVS, "$Codestriker::cvs -d " . $self->{cvsroot} .
	 " co -p -r $revision $filename 2>/dev/null |")
	|| die "Can't open connection to local CVS repository: $!";

    # Read the data.
    for (my $i = 1; <CVS>; $i++) {
	chop;
	$$content_array_ref[$i] = $_;
    }
    close CVS;
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
    my $viewer = $Codestriker::file_viewer->{$self->{cvsroot}};
    return (defined $viewer) ? $viewer . "/" . $filename : "";
}

# Return a string representation of this repository.
sub toString ($) {
    my ($self) = @_;
    return $self->getRoot();
}

1;
