# Tests for the ListTopics method.

use strict;
use Test::More tests => 2;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::ListTopicsMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

my $url_cgi = Codestriker::Http::Method::ListTopicsMethod->new($mock_query);

# Test list topics URL generation.
is ($url_cgi->url(sauthor => "sits", sreviewer => "engineering",
                  sbugid => "10,20", stitle => "Example title",
                  scomments => "Critical Error",
                  sstate => [0],
                  sproject => [10,20]),
    $mock_query->url() . '?action=list_topics&sauthor=sits&sreviewer=engineering' .
                         '&sbugid=10%2C20&stitle=Example%20title&scomments=Critical%20Error' .
                         '&sstate=0&sproject=10%2C20',
    "List topics URL CGI syntax");

# Test list topics RSS URL generation.
is ($url_cgi->url(sauthor => "sits", sreviewer => "engineering",
                  sbugid => "10,20", stitle => "Example title",
                  scomments => "Critical Error",
                  sstate => [0],
                  sproject => [10,20], rss => 1),
    $mock_query->url() . '?action=list_topics_rss&sauthor=sits&sreviewer=engineering' .
                         '&sbugid=10%2C20&stitle=Example%20title&scomments=Critical%20Error' .
                         '&sstate=0&sproject=10%2C20',
    "List topics URL CGI syntax");
