
# make sure if we don't have any repo configured that all traces of repo's 
# are gone from the system.

use strict;
use warnings;

use Test::More tests => 17;

use CodestrikerTest::Config;
use CodestrikerTest::MainPage;
use CodestrikerTest::Page;
use CodestrikerTest::PageFactory;
use CodestrikerTest::Util;

CodestrikerTest::Config::ProcessCommandLine();

my $rep_label = "Repository:";

my $main = CodestrikerTest::PageFactory->CreatePage($CodestrikerTest::Config::main_url);

my $newTopic = $main->GetNewTopicPage();

# add page, should be present.
my $new_page_content = $newTopic->GetPageContent();
ok( $new_page_content =~ /$rep_label/,"make sure that $rep_label is in the page");


my $properties = $main->MakeAndNavigateToNewTopic()->GetLink('Topic Properties');
ok( $properties,"get topic properties page");

$new_page_content = $properties->GetPageContent();
ok( $new_page_content =~ /$rep_label/,"make sure that $rep_label is in the page");


CodestrikerTest::Config::SetConfigOption(qq|\@valid_repositories = ();|);

ok( $newTopic->Get(),"get new topic page");

$new_page_content = $newTopic->GetPageContent();
ok( $new_page_content =~ /$rep_label/ == 0,"make sure that $rep_label is not the page");

ok( $properties->Get(),"get new topic page");
$new_page_content = $properties->GetPageContent();
ok( $new_page_content =~ /$rep_label/ == 0,"make sure that $rep_label is not in the page");


0;

