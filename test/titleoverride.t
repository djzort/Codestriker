
# test script to test the ability of the user to override the title of codestriker
# from the configuration file. It is also a way to test the ability of the test
# scripts to override codestriker conf file.

use strict;
use warnings;

use Test::More tests => 20;
use CodestrikerTest::Config;
use CodestrikerTest::MainPage;

CodestrikerTest::Config::ProcessCommandLine();

my @titles = ( 
    "Codestriker \$Codestriker::VERSION",
    "My Title Custom Title",
    "My Codestriker \$Codestriker::VERSION",
    "My HTML title <p>",
    );

foreach my $title_test (@titles)
{
    CodestrikerTest::Config::SetConfigOption(qq|\$title = "$title_test";|);

    my $main = CodestrikerTest::PageFactory->CreatePage($CodestrikerTest::Config::main_url);

    ok($main->Get(),"get main page");

    my $actual_title_name = $title_test;

    my $version = $CodestrikerTest::Config::version;

    $actual_title_name =~ s/\$Codestriker::VERSION/$version/;

    ok( my $home = $main->GetLink($actual_title_name) ,"press title link $actual_title_name");

    my $newTopic = $main->GetNewTopicPage();

    ok( $newTopic ,"get new topic page for $actual_title_name");

    ok( $home = $newTopic->GetLink($actual_title_name) ,"press title link $actual_title_name");
}

0;
