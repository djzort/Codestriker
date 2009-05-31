###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for logging out.

package Codestriker::Action::Logout;

use strict;
use Codestriker::Http::UrlBuilder;
use Codestriker::Http::Cookie;

sub process {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Zap the cookie's password_hash, and redirect to the login page.
    my %cookie = Codestriker::Http::Cookie->get($query);
    $cookie{'password_hash'} = '';
    my $cookie_obj = Codestriker::Http::Cookie->make($query, \%cookie);
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    print $query->redirect(-cookie => $cookie_obj,
                           -location => $url_builder->login_url());
}

1;
