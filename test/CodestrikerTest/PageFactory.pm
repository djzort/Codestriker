
package CodestrikerTest::PageFactory;

use CodestrikerTest::Page;
use CodestrikerTest::MainPage;
use CodestrikerTest::NewTopicPage;
use CodestrikerTest::SearchPage;
use CodestrikerTest::TopicPropertiesPage;
use CodestrikerTest::TopicContentPage;
use CodestrikerTest::CommentPage;

use strict;
use warnings;


# Factory method for creating the correct type of page object for the given 
# url.
sub CreatePage
{
    my ($class,$url) = @_;

    $url =~ /action=([a-zA-Z_]+)/;

    my $actionName = $1;

    if ( !defined($actionName) || $actionName eq "" || $actionName eq "list_topics")
    {
	return CodestrikerTest::MainPage->new($url);
    }
    elsif ( defined($actionName) && $actionName eq "create")
    {
        return CodestrikerTest::NewTopicPage->new($url);
    }
    elsif ( defined($actionName) && $actionName eq "search")
    {
        return CodestrikerTest::SearchPage->new($url);
    }
    elsif ( defined($actionName) && $actionName eq "view_topic_properties") 
    {
        return CodestrikerTest::TopicPropertiesPage->new($url);        
    }
    elsif ( defined($actionName) && $actionName eq "view") 
    {
        return CodestrikerTest::TopicContentPage->new($url);        
    }

    return CodestrikerTest::Page->new($url);

}

1;


