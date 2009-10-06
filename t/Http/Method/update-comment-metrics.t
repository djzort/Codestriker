# Tests for the UpdateCommentMetrics method.

use strict;
use Test::More tests => 1;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::UpdateCommentMetricsMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::UpdateCommentMetricsMethod->new($mock_query);

is($url_cgi->url(topicid => 1234, projectid => 10),
   $mock_query->url() . '?action=change_comments_state',
   "Update comment metrics URL CGI syntax");
