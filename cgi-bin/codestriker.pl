#!/usr/bin/perl -wT

###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
# Version 1.5
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# This is the top level package which receives all HTTP requests, and
# delegates it to the appropriate Action module.

require 5.000;

use strict;

use CGI qw/:standard :html3/;
use CGI::Carp 'fatalsToBrowser';

# Location of codestriker distribution, which contains the configuration file
# and the codestriker modules.
my $codestriker_dir = "/var/www/codestriker";
use lib "/var/www/codestriker/lib";

use Codestriker;
use Codestriker::Http::Input;
use Codestriker::Http::Response;
use Codestriker::Action::CreateTopic;
use Codestriker::Action::SubmitTopic;
use Codestriker::Action::ViewTopic;
use Codestriker::Action::EditTopic;
use Codestriker::Action::SubmitComment;
use Codestriker::Action::ViewFile;

# Set the PATH to something sane.
$ENV{'PATH'} = "/bin:/usr/bin";

# Prototypes of subroutines used in this module.
sub main();

main;

sub main() {
    # Initialise Codestriker, load up the configuration file.
    Codestriker->initialise();

    # Load the CGI object, and prepare the HTTP response.
    my $query = new CGI;
    my $http_response = Codestriker::Http::Response->new($query);

    # Process the HTTP input to ensure it is consistent.
    my $http_input = Codestriker::Http::Input->new($query, $http_response);
    $http_input->process();

    # Delegate the request to the appropriate Action module.
    my $action = $http_input->get("action");
    if (! defined $action || $action eq "" || $action eq "create") {
	Codestriker::Action::CreateTopic->process($http_input, $http_response);
    } elsif ($action eq "submit_topic") {
	Codestriker::Action::SubmitTopic->process($http_input, $http_response);
    } elsif ($action eq "view") {
	Codestriker::Action::ViewTopic->process($http_input, $http_response);
    } elsif ($action eq "edit") {
	Codestriker::Action::EditTopic->process($http_input, $http_response);
    } elsif ($action eq "submit_comment") {
	Codestriker::Action::SubmitComment->process($http_input,
						    $http_response);
    } elsif ($action eq "view_file") {
	Codestriker::Action::ViewFile->process($http_input, $http_response);
    }

    # Output the HTML footer, and return.
    $http_response->generate_footer();
}
