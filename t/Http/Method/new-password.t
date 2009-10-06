# Tests for the NewPassword method.

use strict;
use Test::More tests => 1;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::NewPasswordMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::NewPasswordMethod->new($mock_query);

is($url_cgi->url(email => 'joe@bloggs.com',
                 challenge => 'abcdefg'),
   $mock_query->url() . '?action=new_password&email=joe%40bloggs.com&challenge=abcdefg',
   "New password URL CGI syntax");
