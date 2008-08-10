# Tests for the AddComment method.

use strict;
use Test::More tests => 8;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::AddCommentMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

# Create two method objects to test each URL scheme.
my $url_cgi = Codestriker::Http::Method::AddCommentMethod->new($mock_query, 1);
my $url_nice = Codestriker::Http::Method::AddCommentMethod->new($mock_query, 0);

is($url_cgi->url(filenumber => 3, line => 55, new => 0, topicid => 1234,
                 projectid => 10, context => 3),
   $mock_query->url() . '?action=edit&fn=3&line=55&new=0&topic=1234&context=3',
   "Add comment URL CGI syntax");
   
is($url_nice->url(filenumber => 3, line => 55, new => 0, topicid => 1234,
                  projectid => 10, context => 3),
   $mock_query->url() . '/project/10/topic/1234/comment/3|55|0/add/context/3',
   "Add comment URL nice syntax");

# Check that the parameters extracted correctly.
my $mock_http_input = Test::MockObject->new();
$mock_http_input->{query} = $mock_query;
$mock_query->mock('path_info',
                  sub {
                  	return $mock_query->url() . '/project/10/topic/1234/comment/3|55|0/add/context/3';
                  });
$mock_query->mock('param', sub { return undef; });                  
$url_nice->extract_parameters($mock_http_input);
is ($mock_http_input->{projectid}, "10", "projectid nice URL parameter extraction");
is ($mock_http_input->{topicid}, "1234", "topicid nice URL parameter extraction");
is ($mock_http_input->{fn}, "3", "fn nice URL parameter extraction");
is ($mock_http_input->{line}, "55", "line nice URL parameter extraction");
is ($mock_http_input->{new}, "0", "new nice URL parameter extraction");
is ($mock_http_input->{context}, "3", "context nice URL parameter extraction");

                              