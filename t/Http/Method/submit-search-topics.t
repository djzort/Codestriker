# Tests for the SubmitSearchTopics method.

use strict;
use Test::More tests => 1;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::SubmitSearchTopicsMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::SubmitSearchTopicsMethod->new($mock_query);

is($url_cgi->url(), $mock_query->url() . '?action=submit_search',
   "Search URL CGI syntax");
