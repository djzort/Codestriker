# Tests for the ViewTopicProperties method.

use strict;
use Test::More tests => 4;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::ViewTopicPropertiesMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

# Create two method objects to test each URL scheme.
my $url_cgi = Codestriker::Http::Method::ViewTopicPropertiesMethod->new($mock_query, 1);
my $url_nice = Codestriker::Http::Method::ViewTopicPropertiesMethod->new($mock_query, 0);

is($url_cgi->url(topicid => 1234, projectid => 10),
   $mock_query->url() . '?action=view_topic_properties&topic=1234',
   "View topic properties URL CGI syntax");
   
is($url_nice->url(topicid => 1234, projectid => 10),
   $mock_query->url() . '/project/10/topic/1234/properties/view',
   "View topic properties URL nice syntax");

# Check that the parameters extracted correctly.
my $mock_http_input = Test::MockObject->new();
$mock_http_input->{query} = $mock_query;
$mock_http_input->mock('extract_cgi_parameters', sub { return undef; });                  
$mock_query->mock('path_info',
                  sub {
                  	return '/project/10/topic/1234/properties/view';
                  });
$mock_query->mock('param', sub { return undef; });                  
$url_nice->extract_parameters($mock_http_input);
is ($mock_http_input->{projectid}, "10", "project nice URL parameter extraction");
is ($mock_http_input->{topic}, "1234", "topicid nice URL parameter extraction");

                              