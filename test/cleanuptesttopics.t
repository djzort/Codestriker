
use strict;
use warnings;

use Test::More qw(no_plan);

use CodestrikerTest::Config;
use CodestrikerTest::MainPage;
use CodestrikerTest::Page;
use CodestrikerTest::PageFactory;
use CodestrikerTest::Util;

CodestrikerTest::Config::ProcessCommandLine();

# create page with no params
my $main = CodestrikerTest::PageFactory->CreatePage($CodestrikerTest::Config::main_url);

my $searchPage = $main->GetLink("Search");

my $searchResult = $searchPage->SubmiteSearch(state_group=>'Any',stext=>$topicTitlePrefix);

my @topics = $searchResult->GetTopics();

foreach my $topic (@topics)
{
    my $topic_content = $searchResult->GetLink($topic->{title});

    ok( $topic_content,"get topic content page for $topic->{title}");

    my $properties = $topic_content->GetLink('Topic Properties');

    ok( $properties->SetTopicProperties( topic_state=>'Delete'),"delete topic $topic->{title}");

}

exit(0);

