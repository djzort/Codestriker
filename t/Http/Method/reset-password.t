# Tests for the ResetPassword method.

use strict;
use Test::More tests => 1;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::ResetPasswordMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::ResetPasswordMethod->new($mock_query);

is($url_cgi->url(email => 'joe@bloggs.com'),
   $mock_query->url() . '?action=reset_password',
   "Reset password URL CGI syntax");
