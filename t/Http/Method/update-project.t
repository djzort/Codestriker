# Tests for the UpdateProject method.

use strict;
use Test::More tests => 1;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::UpdateProjectMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::UpdateProjectMethod->new($mock_query);

is($url_cgi->url(45), $mock_query->url() . '?action=submit_editproject',
   "Update project URL CGI syntax");
