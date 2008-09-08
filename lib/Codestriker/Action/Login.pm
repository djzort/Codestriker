###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying the login page.

package Codestriker::Action::Login;

use strict;
use Codestriker::Http::UrlBuilder;

# Create an appropriate form for logging in.
sub process {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    $http_response->generate_header(topic_title=>"Login",
                                    reload=>0, cache=>1);

    # Target URL to divert the post to.
    my $vars = {};
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);
    $vars->{'action_url'} = $url_builder->authenticate_url();
    $vars->{'new_user_url'} = $url_builder->create_new_user_url();
    $vars->{'reset_password_url'} = $url_builder->reset_password_url();
    $vars->{'redirect'} = $http_input->get('redirect');
    $vars->{'feedback'} = $http_input->get('feedback');

    my $template = Codestriker::Http::Template->new("login");
    $template->process($vars);

    $http_response->generate_footer();
}

1;
