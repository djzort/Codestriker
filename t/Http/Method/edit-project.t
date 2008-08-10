# Tests for the EditProject method.

use strict;
use Test::More tests => 3;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::EditProjectMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

# Create two method objects to test each URL scheme.
my $url_cgi = Codestriker::Http::Method::EditProjectMethod->new($mock_query, 1);
my $url_nice = Codestriker::Http::Method::EditProjectMethod->new($mock_query, 0);

is($url_cgi->url(45), $mock_query->url() . '?action=edit_project&projectid=45',
   "List projects URL CGI syntax");
is($url_nice->url(45), $mock_query->url() . '/admin/project/45/edit',
   "List projects URL nice syntax");

# Check that the parameters extracted correctly.
my $mock_http_input = Test::MockObject->new();
$mock_http_input->{query} = $mock_query;
$mock_query->mock('path_info',
                  sub {
                  	return $mock_query->url() . '/admin/project/45/edit';
                  });
$mock_query->mock('param', sub { return undef; });                  
$url_nice->extract_parameters($mock_http_input);
is ($mock_http_input->{projectid}, "45", "projectid nice URL parameter extraction");

                              