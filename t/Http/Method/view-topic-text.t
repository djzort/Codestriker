# Tests for the ViewTopicText method.

use strict;
use Test::More tests => 7;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::ViewTopicTextMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

# Create two method objects to test each URL scheme.
my $url_cgi = Codestriker::Http::Method::ViewTopicTextMethod->new($mock_query, 1);
my $url_nice = Codestriker::Http::Method::ViewTopicTextMethod->new($mock_query, 0);

is($url_cgi->url(topicid => 1234, projectid => 10, filenumber => 2, line => 3, new => 1),
   $mock_query->url() . '?action=view&topic=1234#2|3|1',
   "View URL CGI syntax");
   
is($url_nice->url(topicid => 1234, projectid => 10, filenumber => 2, line => 3, new => 1),
   $mock_query->url() . '/project/10/topic/1234/text#2|3|1',
   "View URL nice syntax");
   
is($url_cgi->url(topicid => 1234, projectid => 10, filenumber => 2, line => 3, new => 1, fview => 2),
   $mock_query->url() . '?action=view&topic=1234&fview=2#2|3|1',
   "View URL CGI syntax specific file");
   
is($url_nice->url(topicid => 1234, projectid => 10, filenumber => 2, line => 3, new => 1, fview => 2),
   $mock_query->url() . '/project/10/topic/1234/text/filenumber/2#2|3|1',
   "View URL nice syntax specific file");

# Check if parameters are missing.
eval {
	$url_cgi->url(projectid => 10, filenumber => 2, line => 3, new => 1);
	fail("View URL missing topicid parameter");
};
if ($@) {
	# Expected.
	pass("View URL missing topicid parameter");
}   

# Check that the parameters extracted correctly.
my $mock_http_input = Test::MockObject->new();
$mock_http_input->{query} = $mock_query;
$mock_http_input->mock('extract_cgi_parameters', sub { return undef; });                  
$mock_query->mock('path_info',
                  sub { '/project/10/topic/1234/text#2|3|1'; });
$mock_query->mock('param', sub { return undef; });                  
$url_nice->extract_parameters($mock_http_input);
is ($mock_http_input->{projectid}, "10", "project nice URL parameter extraction");
is ($mock_http_input->{topic}, "1234", "topicid nice URL parameter extraction");

                              