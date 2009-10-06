# Tests for the ViewTopicText method.

use strict;
use Test::More tests => 3;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::ViewTopicTextMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::ViewTopicTextMethod->new($mock_query);

is($url_cgi->url(topicid => 1234, projectid => 10, filenumber => 2, line => 3, new => 1),
   $mock_query->url() . '?action=view&topic=1234#2|3|1',
   "View URL CGI syntax");

is($url_cgi->url(topicid => 1234, projectid => 10, filenumber => 2, line => 3, new => 1, fview => 2),
   $mock_query->url() . '?action=view&topic=1234&fview=2#2|3|1',
   "View URL CGI syntax specific file");

# Check if parameters are missing.
eval {
	$url_cgi->url(projectid => 10, filenumber => 2, line => 3, new => 1);
	fail("View URL missing topicid parameter");
};
if ($@) {
	# Expected.
	pass("View URL missing topicid parameter");
}
