# Tests for the CreateTopic method.

use strict;
use Test::More tests => 5;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::CreateTopicMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

# Create two method objects to test each URL scheme.
my $url_cgi = Codestriker::Http::Method::CreateTopicMethod->new($mock_query, 1);
my $url_nice = Codestriker::Http::Method::CreateTopicMethod->new($mock_query, 0);

is($url_cgi->url(),
   $mock_query->url() . '?action=create',
   "Create topic URL CGI syntax");
   
is($url_nice->url(),
   $mock_query->url() . '/topics/create',
   "Create topic URL nice syntax");

is($url_cgi->url(45),
   $mock_query->url() . '?action=create&obsoletes=45',
   "Create topic with obsolete topics URL CGI syntax");
   
is($url_nice->url(45),
   $mock_query->url() . '/topics/create/obsoletes/45',
   "Create topic with obsolete topics URL nice syntax");

# Check that the parameters extracted correctly.
my $mock_http_input = Test::MockObject->new();
$mock_http_input->{query} = $mock_query;
$mock_http_input->mock('extract_cgi_parameters', sub { return undef; });                  
$mock_query->mock('path_info',
                  sub {
                  	return '/topics/create/obsoletes/45';
                  });
$mock_query->mock('param', sub { return undef; });                  
$url_nice->extract_parameters($mock_http_input);
is ($mock_http_input->{obsoletes}, "45", "obsoletes nice URL parameter extraction");

                              