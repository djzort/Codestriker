# Tests for the CreateTopic method.

use strict;
use Test::More tests => 2;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::CreateTopicMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::CreateTopicMethod->new($mock_query);

is($url_cgi->url(),
   $mock_query->url() . '?action=create',
   "Create topic URL CGI syntax");
is($url_cgi->url(45),
   $mock_query->url() . '?action=create&obsoletes=45',
   "Create topic with obsolete topics URL CGI syntax");
