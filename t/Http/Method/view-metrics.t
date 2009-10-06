# Tests for the ViewMetrics method.

use strict;
use Test::More tests => 1;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::ViewMetricsMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::ViewMetricsMethod->new($mock_query);

is($url_cgi->url(),
   $mock_query->url() . '?action=metrics_report',
   "View metric reports URL CGI syntax");
