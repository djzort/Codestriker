
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

my $newTopic = $main->GetNewTopicPage();

ok( $newTopic );

my $confirmPage;

my $titleName = MakeNewTopicName();

$confirmPage = $newTopic->CreateNewTopic(
    topic_title=>$titleName,
    topic_description=>'d',
    email=>$CodestrikerTest::Config::email_adddress[0] ,
    reviewers=>$CodestrikerTest::Config::email_adddress[1],
    topic_file=>'newtopic.t');

ok( $confirmPage->TopicCreated(),"normal text file create" );

ok( $main->Get(),'refresh main page to get new topic');

my $topic_content = $main->GetLink($titleName);

ok( $topic_content,"get topic content page");

my $properties = $topic_content->GetLink('Topic Properties');

ok( $properties->SetTopicProperties( topic_state=>'Delete'),"change delete");

my $searchPage = $main->GetLink("Search");

my $searchResult = $searchPage->SubmiteSearch(state_group=>'Any',stext=>$titleName);

ok( !$searchResult->GetLink($titleName) , "make title \"$titleName\" is gone.");

exit(0);

