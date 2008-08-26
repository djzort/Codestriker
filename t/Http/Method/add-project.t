# Tests for the AddProject method.

use strict;
use Test::More tests => 2;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::AddProjectMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

# Create two method objects to test each URL scheme.
my $url_cgi = Codestriker::Http::Method::AddProjectMethod->new($mock_query, 1);
my $url_nice = Codestriker::Http::Method::AddProjectMethod->new($mock_query, 0);

is($url_cgi->url(), $mock_query->url() . '?action=submit_project',
   "Add project URL CGI syntax");
is($url_nice->url(), $mock_query->url() . '/admin/projects/add',
   "Add project URL nice syntax");                       
