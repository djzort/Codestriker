# Tests for the UpdateTopicStates method.

use strict;
use Test::More tests => 1;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::UpdateTopicStateMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::UpdateTopicStateMethod->new($mock_query);

is($url_cgi->url(projectid => 10),
   $mock_query->url() . '?action=change_topics_state',
   "Update topic state URL CGI syntax");
