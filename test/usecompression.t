
use strict;
use warnings;

use Test::More qw(no_plan);

use CodestrikerTest::Config;
use CodestrikerTest::MainPage;
use CodestrikerTest::Page;
use CodestrikerTest::PageFactory;
use CodestrikerTest::Util;

CodestrikerTest::Config::ProcessCommandLine();

# make sure we can do this not compressed.
CodestrikerTest::Config::SetConfigOption(qq|\$use_compression = 0;|);

my $main = CodestrikerTest::PageFactory->CreatePage($CodestrikerTest::Config::main_url);

ok( $main->IsCompressed() == 0,"main not IsCompressed" );

# now do the rest of the test compressed.
CodestrikerTest::Config::SetConfigOption(qq|\$use_compression = 1;|);

my $commpressed_comment_tag = "Source was sent compressed.";

# create page with no params
$main = CodestrikerTest::PageFactory->CreatePage($CodestrikerTest::Config::main_url);

ok( $main->IsCompressed(),"main IsCompressed" );

my $newTopic = $main->GetNewTopicPage();

ok( $newTopic,"Verify new topic page" );

ok( $newTopic->{response}->content =~ /$commpressed_comment_tag/ , "look $commpressed_comment_tag comment");

my $confirmPage;

my $titleName = MakeNewTopicName();

$confirmPage = $newTopic->CreateNewTopic(
    topic_title=>$titleName,
    topic_description=>'d',
    email=>$CodestrikerTest::Config::email_adddress[0] ,
    reviewers=>$CodestrikerTest::Config::email_adddress[1],
    topic_file=>'newtopic.t');

ok( $confirmPage->TopicCreated(),"create topic \"$titleName\"" );

ok( $confirmPage->IsCompressed(),"confirmPage IsCompressed" );

ok($main->Get(),"get main page");
    
ok( my $topic_content = $main->GetLink($titleName),"get link \"$titleName\"");

ok( $topic_content->IsCompressed(),"IsCompressed" );


0;

