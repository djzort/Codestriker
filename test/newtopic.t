
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

my $bad_email = "bademail<pre>";

$confirmPage = $newTopic->CreateNewTopic(
    topic_title=>MakeNewTopicName(),
    topic_description=>'d',
    email=>$CodestrikerTest::Config::email_adddress[0] ,
    reviewers=>$CodestrikerTest::Config::email_adddress[1],
    topic_file=>'newtopic.t');

ok( $confirmPage->TopicCreated(),"normal text file create" );

ok( $confirmPage->LintPageHTML() == 0,"lint confirm page");

$confirmPage = $newTopic->CreateNewTopic(
    topic_description=>'d',
    email=>$CodestrikerTest::Config::email_adddress[0],
    reviewers=>$CodestrikerTest::Config::email_adddress[1],
    topic_file=>'newtopic.t');

ok( $confirmPage->TopicCreated() == 0,"missing title");


$confirmPage = $newTopic->CreateNewTopic(
    topic_title=>MakeNewTopicName(),
    email=>$CodestrikerTest::Config::email_adddress[0],
    reviewers=>$CodestrikerTest::Config::email_adddress[1],
    topic_file=>'newtopic.t');

ok( $confirmPage->TopicCreated() == 0,"missing description" );

$confirmPage = $newTopic->CreateNewTopic(
    topic_title=>MakeNewTopicName(),
    topic_description=>'d',
    reviewers=>$CodestrikerTest::Config::email_adddress[1],
    topic_file=>'newtopic.t');

ok( $confirmPage->TopicCreated() == 0,"missing email" );

$confirmPage = $newTopic->CreateNewTopic(
    topic_title=>MakeNewTopicName(),
    topic_description=>'d',
    email=>$CodestrikerTest::Config::email_adddress[0],
    topic_file=>'newtopic.t');

ok( $confirmPage->TopicCreated() == 0,"missing reviewers" );

$confirmPage = $newTopic->CreateNewTopic(
    topic_title=>MakeNewTopicName(),
    topic_description=>'d',
    email=>$CodestrikerTest::Config::email_adddress[0],
    reviewers=>$CodestrikerTest::Config::email_adddress[1]);

ok( $confirmPage->TopicCreated() == 0,"missing file" );

$confirmPage = $newTopic->CreateNewTopic(
    topic_title=>MakeNewTopicName(),
    topic_description=>'d',
    email=>$bad_email,
    reviewers=>$CodestrikerTest::Config::email_adddress[1],
    topic_file=>'newtopic.t');

ok( $confirmPage->TopicCreated() == 0,"malformed author" );

$confirmPage = $newTopic->CreateNewTopic(
    topic_title=>MakeNewTopicName(),
    topic_description=>'d',
    email=>$CodestrikerTest::Config::email_adddress[0],
    reviewers=>$bad_email,
    topic_file=>'newtopic.t');

ok( $confirmPage->TopicCreated() == 0,"malformed reviewer" );

$confirmPage = $newTopic->CreateNewTopic(
    topic_title=>MakeNewTopicName(),
    topic_description=>'d',
    email=>$CodestrikerTest::Config::email_adddress[0],
    reviewers=>$CodestrikerTest::Config::email_adddress[1],
    topic_file=>'newtopic.t',
    cc=>$bad_email);

ok( $confirmPage->TopicCreated() == 0,"malformed cc" );

# if html is not escaped out properly the lint will fail.
$confirmPage = $newTopic->CreateNewTopic(
    topic_title=>MakeNewTopicName() . " <TABLE><PRE>",
    topic_description=>'d',
    email=>$CodestrikerTest::Config::email_adddress[0],
    reviewers=>$CodestrikerTest::Config::email_adddress[1],
    topic_file=>'newtopic.t');

ok( $confirmPage->TopicCreated(),"normal text file create, with html tag" );

ok( $confirmPage->LintPageHTML() == 0,"lint with html characters");

exit(0);

