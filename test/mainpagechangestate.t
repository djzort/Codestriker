
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

my $searchPage = $main->GetLink("Search");
    

ok( $searchPage->Get() ,"get search page" );

my $titlePrefix = MakeNewTopicName();

my @titles = (
    $titlePrefix . " main page state change 1",
    $titlePrefix . " main page state change 2",
    $titlePrefix . " main page state change 3",
    $titlePrefix . " main page state change 4" );

foreach my $title (@titles)
{
    CreateTopic($title);
}

TestChangeState('Closed',1,2,3,4); # all of them

TestChangeState('Closed',1); # first closed

TestChangeState('Closed'); # closed, none selected

TestChangeState('Closed',4); # close, last selected

TestChangeState('Open',1,2,3,4); # all of the back open, mixed state

if ($CodestrikerTest::Config::run_quick == 0)
{
    print "# random stress test\n";
    srand(0);

    for (my $cycle = 0; $cycle < 20; ++$cycle)
    {
        my @states = ('Open','Closed','Committed');

        my $new_state = int(rand()*3);
    
        my @indexs;

        for ( my $topic_index = 1; $topic_index <= 4; ++$topic_index)
        {
            push @indexs, $topic_index if rand() > 0.5;
        } 

        TestChangeState($states[$new_state],@indexs)
    }
}


TestChangeState('Open',1,2,3,4); # commit them all out

print "# Do a duplicate post, make sure it rejects the second post\n";

my $searchResults = $searchPage->SubmiteSearch(stext=>$titlePrefix,state_group=>['Any',undef,undef,undef]);
is( $searchResults->GetNumberOfTopics(),
    scalar( @titles ),
    "make sure title search returns " . scalar( @titles ) . " topics");

my $searchResults2 = $searchPage->SubmiteSearch(stext=>$titlePrefix,state_group=>['Any',undef,undef,undef]);


$searchResults->ChangeTopicStates("Closed",1);

$searchResults2->ChangeTopicStates("Committed",1);

$searchResults = $searchPage->SubmiteSearch(stext=>$titlePrefix,state_group=>[undef,undef,'Closed',undef]);
is( $searchResults->GetNumberOfTopics(),
    1,
    "still set to closed");

TestChangeState('Committed',1,2,3,4); # commit them all out

exit(0);


sub TestChangeState
{
    my ($new_state,@topic_index) = @_;
    
    print "# TestChangeState(" . join(',',@_) . ")\n";

    my $searchResults = $searchPage->SubmiteSearch(stext=>$titlePrefix,state_group=>['Any',undef,undef,undef]);
    is( $searchResults->GetNumberOfTopics(),
        scalar( @titles ),
        "make sure title search returns " . scalar( @titles ) . " topics");
    
    $searchResults->ChangeTopicStates($new_state,@topic_index);

    # refresh
    $searchResults = $searchPage->SubmiteSearch(stext=>$titlePrefix,state_group=>['Any',undef,undef,undef]);

    my @topics = $searchResults->GetTopics();

    foreach my $topic_index (@topic_index)
    {
        is( $topics[$topic_index-1]->{state},$new_state,"verify that $topics[$topic_index-1]->{title} state == $new_state");
    }
}


sub CreateTopic
{
    my ($title) = @_;

    my $newTopic = $main->GetNewTopicPage();

    ok( $newTopic , "new topic page exists");

    my $confirmPage = $newTopic->CreateNewTopic(
        topic_title=>$title,
        topic_description=>'description',
        email=>$CodestrikerTest::Config::email_adddress[0],
        reviewers=>$CodestrikerTest::Config::email_adddress[1],
        topic_file=>'testtopictexts/txt-htmlfile.txt',
        cc=>'');

    ok( $confirmPage->TopicCreated(),"created topic $title" );

}