# Tests to ensure that UrlBuilder produces correct URLs.

use strict;
use Test::More tests => 40;

use lib '../../lib';
use Test::MockObject;
use Codestriker;
use Codestriker::Http::UrlBuilder;

# Create a CGI mock object for these tests.
my $mock_query = Test::MockObject->new();
$mock_query->mock('url',
            sub { 'http://localhost.localdomain/codestriker/codestriker.pl' } );


# Test view URL generation.
my $url_cgi = Codestriker::Http::UrlBuilder->new($mock_query);
my $url_nice = Codestriker::Http::UrlBuilder->new($mock_query, 0);

is($url_cgi->view_url(topicid => 1234, projectid => 10, filenumber => 2, line => 3, new => 1),
   $mock_query->url() . '?action=view&topic=1234#2|3|1',
   "View URL CGI syntax");
   
is($url_nice->view_url(topicid => 1234, projectid => 10, filenumber => 2, line => 3, new => 1),
   $mock_query->url() . '/project/10/topic/1234/view/text#2|3|1',
   "View URL nice syntax");
   
is($url_cgi->view_url(topicid => 1234, projectid => 10, filenumber => 2, line => 3, new => 1, fview => 2),
   $mock_query->url() . '?action=view&topic=1234&fview=2#2|3|1',
   "View URL CGI syntax specific file");
   
is($url_nice->view_url(topicid => 1234, projectid => 10, filenumber => 2, line => 3, new => 1, fview => 2),
   $mock_query->url() . '/project/10/topic/1234/view/text/filenumber/2#2|3|1',
   "View URL nice syntax specific file");

# Check if parameters are missing.
eval {
	$url_cgi->view_url(projectid => 10, filenumber => 2, line => 3, new => 1);
	fail("View URL missing topicid parameter");
};
if ($@) {
	# Expected.
	pass("View URL missing topicid parameter");
}   

eval {
	$url_cgi->view_url(topicid => 1234, filenumber => 2, line => 3, new => 1);
	fail("View URL missing projectid parameter");
};
if ($@) {
	# Expected.
	pass("View URL missing projectid parameter");
}   

# Test download URL generation.
is($url_cgi->download_url(topicid => 1234, projectid => 10, filenumber => 2, line => 3, new => 1),
   $mock_query->url() . '?action=download&topic=1234',
   "Download URL CGI syntax");
   
is($url_nice->download_url(topicid => 1234, projectid => 10, filenumber => 2, line => 3, new => 1),
   $mock_query->url() . '/project/10/topic/1234/download/text',
   "Download URL nice syntax");
   
# Check if parameters are missing.
eval {
	$url_cgi->download_url(projectid => 10);
	fail("Download URL missing topicid parameter");
};
if ($@) {
	# Expected.
	pass("Download URL missing topicid parameter");
}   

eval {
	$url_cgi->download_url(topicid => 1234);
	fail("Download URL missing projectid parameter");
};
if ($@) {
	# Expected.
	pass("Download URL missing projectid parameter");
}   

# Test create topic URL generation.
is($url_cgi->create_topic_url(),
   $mock_query->url() . '?action=create',
   "Create topic URL CGI syntax");
   
is($url_nice->create_topic_url(),
   $mock_query->url() . '/topics/create',
   "Create topic URL nice syntax");

is($url_cgi->create_topic_url(45),
   $mock_query->url() . '?action=create&obsoletes=45',
   "Create topic with obsolete topics URL CGI syntax");
   
is($url_nice->create_topic_url(45),
   $mock_query->url() . '/topics/create/obsoletes/45',
   "Create topic with obsolete topics URL nice syntax");
   
# Test edit comment URL generation.
is($url_cgi->edit_url(filenumber => 3, line => 55, new => 0, topicid => 1234,
                      projectid => 10, context => 3),
   $mock_query->url() . '?action=edit&fn=3&line=55&new=0&topic=1234&context=3',
   "Add comment URL CGI syntax");
   
is($url_nice->edit_url(filenumber => 3, line => 55, new => 0, topicid => 1234,
                       projectid => 10, context => 3),
   $mock_query->url() . '/project/10/topic/1234/comment/3|55|0/add/context/3',
   "Add comment URL nice syntax");

# Test view file URL generation.
is($url_cgi->view_file_url(filenumber => 3, line => 55, new => 0, topicid => 1234,
                           projectid => 10),
   $mock_query->url() . '?action=view_file&fn=3&topic=1234&new=0#3|55|0',
   "View file URL CGI syntax");
   
is($url_nice->view_file_url(filenumber => 3, line => 55, new => 0, topicid => 1234,
                            projectid => 10),
   $mock_query->url() . '/project/10/topic/1234/view/file/filenumber/3#3|55|0',
   "View file URL nice syntax");
   
# Test search URL generation.
is($url_cgi->search_url(), $mock_query->url() . '?action=search',
   "Search URL CGI syntax");
is($url_nice->search_url(), $mock_query->url() . '/topics/search',
   "Search URL nice syntax");
      
# Test create project URL generation.
is($url_cgi->create_project_url(), $mock_query->url() . '?action=create_project',
   "Create project URL CGI syntax");
is($url_nice->create_project_url(), $mock_query->url() . '/admin/projects/create',
   "Create project URL nice syntax");
   
# Test list project URL generation.
is($url_cgi->list_projects_url(), $mock_query->url() . '?action=list_projects',
   "List projects URL CGI syntax");
is($url_nice->list_projects_url(), $mock_query->url() . '/admin/projects/list',
   "List projects URL nice syntax");                       
   
# Test edit project URL generation.
is($url_cgi->edit_project_url(45), $mock_query->url() . '?action=edit_project&projectid=45',
   "List projects URL CGI syntax");
is($url_nice->edit_project_url(45), $mock_query->url() . '/admin/project/45/edit',
   "List projects URL nice syntax");
   
# Test view comments URL generation.
is($url_cgi->view_comments_url(topicid => 1234, projectid => 10),
   $mock_query->url() . '?action=list_comments&topic=1234',
   "View comments URL CGI syntax");
   
is($url_nice->view_comments_url(topicid => 1234, projectid => 10),
   $mock_query->url() . '/project/10/topic/1234/comments/list',
   "View comments URL nice syntax");

# Test view properties URL generation.
is($url_cgi->view_topic_properties_url(topicid => 1234, projectid => 10),
   $mock_query->url() . '?action=view_topic_properties&topic=1234',
   "View topic properties URL CGI syntax");
   
is($url_nice->view_topic_properties_url(topicid => 1234, projectid => 10),
   $mock_query->url() . '/project/10/topic/1234/properties',
   "View topic properties URL nice syntax");

# Test view topic metrics URL generation.
is($url_cgi->view_topicinfo_url(topicid => 1234, projectid => 10),
   $mock_query->url() . '?action=viewinfo&topic=1234',
   "View topic metrics URL CGI syntax");
   
is($url_nice->view_topicinfo_url(topicid => 1234, projectid => 10),
   $mock_query->url() . '/project/10/topic/1234/metrics',
   "View topic metrics URL nice syntax");
   
# Test metric reports URL generation.
is($url_cgi->metric_report_url(),
   $mock_query->url() . '?action=metrics_report',
   "View metric reports URL CGI syntax");
is($url_nice->metric_report_url(),
   $mock_query->url() . '/metrics/view',
   "View metric reports URL CGI syntax");

is($url_cgi->metric_report_download_raw_data(),
   $mock_query->url() . '?action=metrics_download',
   "Download metrics report URL cgi syntax");
is($url_nice->metric_report_download_raw_data(),
   $mock_query->url() . '/metrics/download',
   "Download metrics report URL nice syntax");
   
# Test list topics URL generation.
is ($url_cgi->list_topics_url(sauthor => "sits", sreviewer => "engineering",
                              sbugid => "10,20", stitle => "Example title",
                              scomments => "Critical Error",
                              sstate => [0],
                              sproject => [10,20]),
    $mock_query->url() . '?action=list_topics&sauthor=sits&sreviewer=engineering' .
                         '&sbugid=10%2C20&stitle=Example%20title&scomments=Critical%20Error' .
                         '&sstate=0&sproject=10%2C20',
    "List topics URL CGI syntax");
is ($url_nice->list_topics_url(sauthor => "sits", sreviewer => "engineering",
                               sbugid => "10,20", stitle => "Example title",
                               scomments => "Critical Error",
                               sstate => [0],
                               sproject => [10,20]),
    $mock_query->url() . '/topics/list/author/sits/reviewer/engineering' .
                         '/bugid/10%2C20/title/Example%20title/comment/Critical%20Error' .
                         '/state/0/project/10%2C20',
    "List topics URL nice syntax");
                              
# Test list topics RSS URL generation.
is ($url_cgi->list_topics_url_rss(sauthor => "sits", sreviewer => "engineering",
                              sbugid => "10,20", stitle => "Example title",
                              scomments => "Critical Error",
                              sstate => [0],
                              sproject => [10,20]),
    $mock_query->url() . '?action=list_topics_rss&sauthor=sits&sreviewer=engineering' .
                         '&sbugid=10%2C20&stitle=Example%20title&scomments=Critical%20Error' .
                         '&sstate=0&sproject=10%2C20',
    "List topics URL CGI syntax");
is ($url_nice->list_topics_url_rss(sauthor => "sits", sreviewer => "engineering",
                               sbugid => "10,20", stitle => "Example title",
                               scomments => "Critical Error",
                               sstate => [0],
                               sproject => [10,20]),
    $mock_query->url() . '/feed/topics/list/author/sits/reviewer/engineering' .
                         '/bugid/10%2C20/title/Example%20title/comment/Critical%20Error' .
                         '/state/0/project/10%2C20',
    "List topics URL nice syntax");
                              