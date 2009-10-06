# Tests for the ViewTopicFile method.

use strict;
use Test::More tests => 1;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::ViewTopicFileMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::ViewTopicFileMethod->new($mock_query);

is($url_cgi->url(filenumber => 3, line => 55, new => 0, topicid => 1234,
                 projectid => 10),
   $mock_query->url() . '?action=view_file&fn=3&topic=1234&new=0#3|55|0',
   "View file URL CGI syntax");
