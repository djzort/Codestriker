# Tests for the SubmitSearchTopics method.

use strict;
use Test::More tests => 2;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::SearchTopicsMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

# Create two method objects to test each URL scheme.
my $url_cgi = Codestriker::Http::Method::SubmitSearchTopicsMethod->new($mock_query, 1);
my $url_nice = Codestriker::Http::Method::SubmitSearchTopicsMethod->new($mock_query, 0);

is($url_cgi->url(), $mock_query->url() . '?action=submit_search',
   "Search URL CGI syntax");
is($url_nice->url(), $mock_query->url() . '/topics/submitsearch',
   "Search URL nice syntax");
