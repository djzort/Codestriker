# Tests for the ResetPassword method.

use strict;
use Test::More tests => 2;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::ResetPasswordMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

# Create two method objects to test each URL scheme.
my $url_cgi = Codestriker::Http::Method::ResetPasswordMethod->new($mock_query, 1);
my $url_nice = Codestriker::Http::Method::ResetPasswordMethod->new($mock_query, 0);

is($url_cgi->url(email => 'joe@bloggs.com'),
   $mock_query->url() . '?action=reset_password',
   "Reset password URL CGI syntax");

is($url_nice->url(email => 'joe@bloggs.com',
                  challenge => 'abcdefg'),
   $mock_query->url() . '/users/reset',
   "Reset password URL nice syntax");
