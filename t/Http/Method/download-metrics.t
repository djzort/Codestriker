# Tests for the DownloadMetrics method.

use strict;
use Test::More tests => 2;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::DownloadMetricsMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

# Create two method objects to test each URL scheme.
my $url_cgi = Codestriker::Http::Method::DownloadMetricsMethod->new($mock_query, 1);
my $url_nice = Codestriker::Http::Method::DownloadMetricsMethod->new($mock_query, 0);

is($url_cgi->url(),
   $mock_query->url() . '?action=metrics_download',
   "Download metrics report URL cgi syntax");
is($url_nice->url(),
   $mock_query->url() . '/metrics/download',
   "Download metrics report URL nice syntax");
