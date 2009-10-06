# Tests for the ViewTopicMetrics method.

use strict;
use Test::More tests => 1;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::ViewTopicMetricsMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::ViewTopicMetricsMethod->new($mock_query);

is($url_cgi->url(topicid => 1234, projectid => 10),
   $mock_query->url() . '?action=viewinfo&topic=1234',
   "View topic metrics URL CGI syntax");
