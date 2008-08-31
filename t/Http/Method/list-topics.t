# Tests for the ListTopics method.

use strict;
use Test::More tests => 11;

use lib '../../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::Method::ListTopicsMethod;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );

# Create two method objects to test each URL scheme.
my $url_cgi = Codestriker::Http::Method::ListTopicsMethod->new($mock_query, 1);
my $url_nice = Codestriker::Http::Method::ListTopicsMethod->new($mock_query, 0);

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
is ($url_nice->url(sauthor => "sits", sreviewer => "engineering",
                   sbugid => "10,20", stitle => "Example title",
                   scomments => "Critical Error",
                   sstate => [0],
                   sproject => [10,20]),
    $mock_query->url() . '/topics/list/author/sits/reviewer/engineering' .
                         '/bugid/10%2C20/title/Example%20title/comment/Critical%20Error' .
                         '/state/0/project/10%2C20',
    "List topics URL nice syntax");
                              
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
is ($url_nice->url(sauthor => "sits", sreviewer => "engineering",
                   sbugid => "10,20", stitle => "Example title",
                   scomments => "Critical Error",
                   sstate => [0], rss => 1,
                   sproject => [10,20]),
    $mock_query->url() . '/feed/topics/list/author/sits/reviewer/engineering' .
                         '/bugid/10%2C20/title/Example%20title/comment/Critical%20Error' .
                         '/state/0/project/10%2C20',
    "List topics URL nice syntax");

# Check that the parameters extracted correctly.
my $mock_http_input = Test::MockObject->new();
$mock_http_input->{query} = $mock_query;
$mock_http_input->mock('extract_cgi_parameters', sub { return undef; });                  
$mock_query->mock('path_info',
                  sub {
                  	return '/topics/list/author/sits/reviewer/engineering' .
                           '/bugid/10%2C20/title/Example%20title/comment/Critical%20Error' .
                           '/state/0/project/10%2C30';
                  });
$mock_query->mock('param', sub { return undef; });                  
$url_nice->extract_parameters($mock_http_input);
is ($mock_http_input->{sauthor}, "sits", "sauthor nice URL parameter extraction");
is ($mock_http_input->{sreviewer}, "engineering", "sreviewer nice URL parameter extraction");
is ($mock_http_input->{sbugid}, "10,20", "sbugid nice URL parameter extraction");
is ($mock_http_input->{stitle}, "Example title", "stitle nice URL parameter extraction");
is ($mock_http_input->{scomments}, "Critical Error", "scomment nice URL parameter extraction");
is ($mock_http_input->{sstate}, "0", "sstate nice URL parameter extraction");
is ($mock_http_input->{sproject}, "10,30", "sproject nice URL parameter extraction");

                              