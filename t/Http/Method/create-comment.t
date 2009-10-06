# Tests for the CreateComment method.

use strict;
use Test::More tests => 1;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::CreateCommentMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::CreateCommentMethod->new($mock_query);

is($url_cgi->url(filenumber => 3, line => 55, new => 0, topicid => 1234,
                 projectid => 10, context => 3),
   $mock_query->url() . '?action=edit&topic=1234&fn=3&line=55&new=0&context=3',
   "Create comment URL CGI syntax");
