###############################################################################
# Codestriker: Copyright (c) 2001,2002,2003 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Base repository object.

package Codestriker::Repository;

# Create a new repository instance.
sub new {
    my ($type, $repository_string) = @_;

    my $self = {};
    $self->{repository_string} = $repository_string;
    return bless $self, $type;
}

# Return a URL which views the specified file and revision.
sub getViewUrl ($$$) {
    my ($self, $filename, $revision) = @_;

    # Lookup the file viewer from the configuration.
    my $viewer = $Codestriker::file_viewer->{$self->toString()};

    # Check in case the user has specified it using the repository string
    # instead of the display string.
    if (! (defined $viewer)) {
        $viewer = $Codestriker::file_viewer->{$self->{repository_string}};
    }

    # If there are CGI parameters in the URL then the file name must
    # be inserted before them; otherwise we simply append it to the end.
    if (defined $viewer) {
        if ($viewer =~ /^([^?]+)(\?.*)$/ ) {
            $viewer = $1 . $filename . $2;
        }
        else {
            $viewer .= '/' . $filename;
        }
    }

    return defined $viewer ? $viewer : "";
}

# Return a string representation of this repository.
sub toString ($) {
    my ($self) = @_;
    return $self->{repository_string};
}

1;
