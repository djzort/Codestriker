# Tests for the Login method.

use strict;
use Test::More tests => 4;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::LoginMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

# Create two method objects to test each URL scheme.
my $url_cgi = Codestriker::Http::Method::LoginMethod->new($mock_query, 1);
my $url_nice = Codestriker::Http::Method::LoginMethod->new($mock_query, 0);

is($url_cgi->url(feedback => 'Incorrect password',
                 redirect => 'http://zot.com/zot.pl?action=blah&param=10'),
   $mock_query->url() . '?action=login&redirect=http%3A%2F%2Fzot.com%2Fzot.pl%3Faction%3Dblah%26param%3D10&feedback=Incorrect%20password',
   "Login URL CGI syntax");
   
is($url_nice->url(feedback => 'Incorrect password',
                  redirect => 'http://zot.com/zot.pl?action=blah&param=10'),
   $mock_query->url() . '/login/form/redirect/http%3A%2F%2Fzot.com%2Fzot.pl%3Faction%3Dblah%26param%3D10/feedback/Incorrect%20password',
   "Login URL nice syntax");

# Check that the parameters extracted correctly.
my $mock_http_input = Test::MockObject->new();
$mock_http_input->{query} = $mock_query;
$mock_http_input->mock('extract_cgi_parameters', sub { return undef; });
$mock_query->mock('path_info',
                  sub {
                  	return '/login/form/redirect/http%3A%2F%2Fzot.com%2Fzot.pl%3Faction%3Dblah%26param%3D10/feedback/Incorrect%20password';
                  });
$mock_query->mock('param', sub { return undef; });                  
$url_nice->extract_parameters($mock_http_input);
is ($mock_http_input->{redirect}, 'http://zot.com/zot.pl?action=blah&param=10', "redirect nice URL parameter extraction");
is ($mock_http_input->{feedback}, 'Incorrect password', "feedback nice URL parameter extraction");
