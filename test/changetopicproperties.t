
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
    email=>$CodestrikerTest::Config::email_adddress[0],
    reviewers=>$CodestrikerTest::Config::email_adddress[1],
    topic_file=>'newtopic.t');

ok( $confirmPage->TopicCreated(),"test topic created" );

# refresh
ok( $main->Get(),"refresh main page to get link to the new topic");

my $topic_content = $main->GetLink($titleName);

ok( $topic_content,"get topic content page");

my $properties = $topic_content->GetLink('Topic Properties');

ok( $properties,"get topic properties page");

TestField( 'topic_title','text',0);
TestField( 'topic_description','text',0);

TestField( 'author','email',0);

TestField( 'reviewers','email_list',0);
TestField( 'cc','email_list',1);


# OK, lets change the states.
my @states = ('Open','Closed','Committed','Open');

foreach my $newState (@states)
{
    ok( $properties->SetTopicProperties( 'topic_state',$newState),"change state to $newState");
    ok( $properties->CompareProperties( 'topic_state',$newState),"verify state to $newState");    
}

ok( $properties->SetTopicProperties( 'topic_state','Delete'),"delete topic, cleanup");

sub TestField
{
    my ($field,$type,$allow_empty) = @_;

    my %orginal_prop = $properties->GetTopicProperties();

    my @new_values;
    my @bad_values;

    if ($type eq 'text')
    {
        push @new_values,'value';
        push @new_values,'<TABLE>';
        push @new_values,'value with spaces numbers 123456789, and symbols !@#$%^&*(){}[]:";<>,./?|\\';        
    }
    elsif ($type eq 'email')
    {
        push @new_values,$CodestrikerTest::Config::email_adddress[0];
        push @new_values,$CodestrikerTest::Config::email_adddress[1];
        push @bad_values,"xxxx";
    }
    elsif ($type eq 'email_list')
    {
        my ( $em1,$em2,$em3) = @CodestrikerTest::Config::email_adddress;

        push @new_values,$em1;
        push @new_values,$em2;
        push @new_values,"$em1,$em2";
        push @new_values,"$em1, $em2";
        push @new_values,"$em1 ,$em2";
        push @new_values,"$em1 , $em2";
        push @new_values,"$em1 ; $em2";
        push @new_values,"$em1;$em2";

        push @new_values," $em1 , $em2 ";

        push @bad_values,"xxxx";
        push @bad_values,"$em1,xxxx";
    }

    if ( $allow_empty )
    {
        push @new_values,"";
    }
    else
    {
        push @bad_values,"";
    }

    foreach my $value (@new_values)
    {
        ok( $properties->SetTopicProperties( $field,$value),"change $field to \"$value\"");
        ok( $properties->CompareProperties( $field,$value),"verify $field was changed \"$value\"");
        is( $properties->LintPageHTML(),0,"lint properties page");
    }

    ok( $properties->SetTopicProperties( %orginal_prop ),"restore properties");

    foreach my $value (@bad_values)
    {
        ok( $properties->SetTopicProperties( $field,$value),"attempt to change $field to $value, expect failure");

        ok( $properties->Get(),"shake off error message");

        ok( $properties->CompareProperties( %orginal_prop),"verify that $field set $value failed");
    }
}

0;