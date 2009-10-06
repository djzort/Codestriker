###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for returning the URL to static resources, such as online help.

package Codestriker::Http::Method::StaticResourcesMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::StaticResourcesMethod::ISA = ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'static');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self) = @_;

    # Check if the HTML files are accessible via another URL (required for
    # sourceforge deployment), which is specified via $Codestriker::codestriker_css.
    my $htmlurl;
    if (defined $Codestriker::codestriker_css &&
        $Codestriker::codestriker_css ne "" &&
        $Codestriker::codestriker_css =~ /[\/\\]/o) {
        $htmlurl = $Codestriker::codestriker_css;
        $htmlurl =~ s/\/.+?\.css//;
    } else {
        # Standard Codestriker deployment.
        $htmlurl = $self->{url_prefix};
        $htmlurl =~ s/codestriker\/codestriker\.pl/codestrikerhtml/;
    }

    return $htmlurl;
}

sub requires_authentication {
    return 0;
}

1;
