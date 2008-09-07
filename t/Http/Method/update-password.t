# Tests for the UpdatePassword method.

use strict;
use Test::More tests => 3;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::UpdatePasswordMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

# Create two method objects to test each URL scheme.
my $url_cgi = Codestriker::Http::Method::UpdatePasswordMethod->new($mock_query, 1);
my $url_nice = Codestriker::Http::Method::UpdatePasswordMethod->new($mock_query, 0);

is($url_cgi->url(email => 'joe@bloggs.com'),
   $mock_query->url() . '?action=update_password&email=joe%40bloggs.com',
   "Update password URL CGI syntax");

is($url_nice->url(email => 'joe@bloggs.com',
                  challenge => 'abcdefg'),
   $mock_query->url() . '/user/joe%40bloggs.com/password/update',
   "Update password URL nice syntax");

# Check that the parameters extracted correctly.
my $mock_http_input = Test::MockObject->new();
$mock_http_input->{query} = $mock_query;
$mock_http_input->mock('extract_cgi_parameters', sub { return undef; });
$mock_query->mock('path_info',
                  sub {
                  	return '/user/joe%40bloggs.com/password/update';
                  });
$mock_query->mock('param', sub { return undef; });
$url_nice->extract_parameters($mock_http_input);
is ($mock_http_input->{email}, 'joe@bloggs.com', "email nice URL parameter extraction");
