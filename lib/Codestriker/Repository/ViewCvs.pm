###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Repository class which retrieves data using viewcvs.cgi.

package Codestriker::Repository::ViewCvs;

use strict;

use LWP::UserAgent;

# Constructor, which takes as a parameter the URL to the viewcvs repository,
# and the CVSROOT.
sub new ($$) {
    my ($type, $viewcvs_url, $cvsroot) = @_;

    my $self = {};
    $self->{viewcvs_url} = $viewcvs_url;
    $self->{cvsroot} = $cvsroot;
    bless $self, $type;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Retrieve the data by doing an HTPP GET to the remote viewcvs server.
    my $ua = LWP::UserAgent->new;
    my $request = $self->{viewcvs_url} .
	"/${filename}?rev=${revision}&content-type=text/plain";
    my $response = $ua->get($request);
    my $content = $response->content;

    # Store the content lines.
    my @content_lines = split /\n/, $content;
    for (my $i = 0; $i <= $#content_lines; $i++) {
	$$content_array_ref[$i+1] = $content_lines[$i];
    }
}

# Retrieve the "root" of this repository.
sub getRoot ($) {
    my ($self) = @_;
    return $self->{cvsroot};
}

# Return a URL which views the specified file.
sub getViewUrl ($$) {
    my ($self, $filename) = @_;

    return $self->{viewcvs_url} . "/" . $filename;
}

# Return a string representation of this repository.
sub toString ($) {
    my ($self) = @_;
    return $self->{viewcvs_url} . " " . $self->{cvsroot};
}

1;
