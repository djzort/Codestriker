
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

ok( $main,"get main page");

my $newTopic = $main->GetNewTopicPage();

ok( $newTopic,"get new topic page");

my $titleName = MakeNewTopicName();


my $confirmPage = $newTopic->CreateNewTopic(
    topic_title=>$titleName,
    topic_description=>'d',
    email=>$CodestrikerTest::Config::email_adddress[0] ,
    reviewers=>$CodestrikerTest::Config::email_adddress[1],
    topic_file=>'newtopic.t');

ok( $confirmPage->TopicCreated(),"test topic created" );

# refresh
ok( $main->Get(),"refresh main page to get link to the new topic");

my $topic_content = $main->GetLink($titleName);

for ( my $comment_line = 1; $comment_line < 5; ++$comment_line)
{
    $topic_content->SubmitComment( 0,$comment_line,1,"new comment line  - $comment_line",$CodestrikerTest::Config::email_adddress[0]);

    ok( $topic_content->Get(), "refresh main topic page to check comment count");

    is( $topic_content->GetCommentCount(),$comment_line,"verify the comment has been added");
}

# comment against full text upload
# comment against diff
# comment on comment

exit(0);

