
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

ok( $newTopic , "new topic page exists");

my $confirmPage;

my $title = MakeNewTopicName() . " HTML escape test <PRE><TABLE>";

$confirmPage = $newTopic->CreateNewTopic(
    topic_title=>$title,
    topic_description=>'description <PRE><TABLE>',
    email=>$CodestrikerTest::Config::email_adddress[0],
    reviewers=>$CodestrikerTest::Config::email_adddress[1],
    topic_file=>'testtopictexts/htmlfile.txt',
    cc=>'');

ok( $confirmPage->TopicCreated(),"normal text file create" );

ok( $confirmPage->LintPageHTML() == 0,"lint confirm page");

ok( $main->Get() );

ok( $main->LintPageHTML() == 0,"lint main page");

my $topic_page = $main->GetLink($title);

my @topic_links = $topic_page->GetLinks();

# lint all of the links from the main topic page, this will be enough to 
# catch any non-escaped topic items.
foreach my $link (@topic_links)
{
    my $page = CodestrikerTest::PageFactory->CreatePage($link->{href});

    if ( $page->Get() && 
         $page->{response}->content_type eq 'text/html' )
    {
        ok( $page->LintPageHTML() == 0,"lint page $link->{href}");
    }
}





exit(0);

