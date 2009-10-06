# Tests for the Login method.

use strict;
use Test::More tests => 1;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::LoginMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::LoginMethod->new($mock_query);

is($url_cgi->url(feedback => 'Incorrect password',
                 redirect => 'http://zot.com/zot.pl?action=blah&param=10'),
   $mock_query->url() . '?action=login&redirect=http%3A%2F%2Fzot.com%2Fzot.pl%3Faction%3Dblah%26param%3D10&feedback=Incorrect%20password',
   "Login URL CGI syntax");
