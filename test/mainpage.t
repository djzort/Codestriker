
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

ok($main->Get(),"get main page");

is( $main->GetTitle(), 'Codestriker: "Topic List"' , "verify title");

# check the home link
ok( my $home = $main->GetLink($CodestrikerTest::Config::title) ,"press title link");

ok( $home->Get(),"get home page from title link" );

is( $home->GetTitle(), 'Codestriker: "Topic List"' );

# the home link page should == to the default home page link, byte for byte.
is( $home->{response}->content, $main->{response}->content );
    

SKIP :
{
    skip "quick flag enabled", 1 if $CodestrikerTest::Config::run_quick;

    # Verifiy links on home page, this is slow.
    ok( $main->VerifyLinks(),"Verify links" );
};


my @topics = $main->GetTopics();

# verify that the topics are sorted correctly.
for (my $count = 0; $count + 1 < scalar(@topics); ++$count)
{
    my $d1 = Date::Calc::Date_to_Time(@{$topics[$count]->{date}});
    my $d2 = Date::Calc::Date_to_Time(@{$topics[$count+1]->{date}});

    ok( $d1 < $d2);
}

for (my $count = 0; $count < scalar(@topics); ++$count)
{
    # The default page should only show open topics.
    is( $topics[$count]->{state},"Open");

    # title, author, and reviewer, can't be empty

    ok( $topics[$count]->{title} ne "");
    ok( $topics[$count]->{author} ne "");
    ok( $topics[$count]->{reviewers} ne "");
}


exit(0);
