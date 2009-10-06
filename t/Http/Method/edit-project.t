# Tests for the EditProject method.

use strict;
use Test::More tests => 1;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::EditProjectMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::EditProjectMethod->new($mock_query);

is($url_cgi->url(45), $mock_query->url() . '?action=edit_project&projectid=45',
   "Edit project URL CGI syntax");
