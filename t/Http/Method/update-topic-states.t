# Tests for the UpdateTopicStates method.

use strict;
use Test::More tests => 3;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::UpdateTopicStateMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

# Create two method objects to test each URL scheme.
my $url_cgi = Codestriker::Http::Method::UpdateTopicStateMethod->new($mock_query, 1);
my $url_nice = Codestriker::Http::Method::UpdateTopicStateMethod->new($mock_query, 0);

is($url_cgi->url(projectid => 10),
   $mock_query->url() . '?action=change_topics_state',
   "Update topic state URL CGI syntax");
   
is($url_nice->url(projectid => 10),
   $mock_query->url() . '/project/10/topic/update',
   "Update topic state URL nice syntax");

# Check that the parameters extracted correctly.
my $mock_http_input = Test::MockObject->new();
$mock_http_input->{query} = $mock_query;
$mock_query->mock('path_info',
                  sub {
                  	return $mock_query->url() . '/project/10/topic/update';
                  });
$mock_query->mock('param', sub { return undef; });                  
$url_nice->extract_parameters($mock_http_input);
is ($mock_http_input->{projectid}, "10", "project nice URL parameter extraction");

                              