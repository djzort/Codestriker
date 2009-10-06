# Tests for the UpdatePassword method.

use strict;
use Test::More tests => 1;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::UpdatePasswordMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::UpdatePasswordMethod->new($mock_query);

is($url_cgi->url(email => 'joe@bloggs.com'),
   $mock_query->url() . '?action=update_password&email=joe%40bloggs.com',
   "Update password URL CGI syntax");
