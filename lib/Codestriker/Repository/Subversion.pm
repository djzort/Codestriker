###############################################################################
# Codestriker: Copyright (c) 2001,2002,2003 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Subversion repository access package.

package Codestriker::Repository::Subversion;

use strict;

# Constructor, which takes as a parameter the repository url.
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

    # Open a pipe to the local CVS repository.
    open(SVN, "svn cat --revision $revision " . $self->{repository_url} .
	 "/$filename 2>/dev/null |")
	|| die "Can't retrieve information from Subversion repository: $!";

    # Read the data.
    for (my $i = 1; <SVN>; $i++) {
	chop;
	$$content_array_ref[$i] = $_;
    }
    close SVN;
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
    return "svn:" . $self->getRoot();
}

1;
