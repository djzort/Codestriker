
package CodestrikerTest::MainPage;

use strict;
use warnings;

use CodestrikerTest::Page;
use CodestrikerTest::Config;
use CodestrikerTest::Util;
use HTML::TokeParser;
use Date::Calc;
use Test::More;

our @ISA = 'CodestrikerTest::Page';

sub new
{
    my ($class,$url) = @_;

    my $self = CodestrikerTest::Page::new($class,$url);

    return $self;

}

# creates a new topic, and navigates into it.
sub MakeAndNavigateToNewTopic
{
    my ($self,%params) = @_;

    unless ( exists($params{topic_title}) )
    {
        my $titleName = MakeNewTopicName();
        $params{topic_title} = $titleName;
    }

    unless ( exists($params{topic_description}) )
    {
        $params{topic_description} = "description";
    }

    unless ( exists($params{email}) )
    {
        $params{email} = $CodestrikerTest::Config::email_adddress[0];
    }

    unless ( exists($params{reviewers}) )
    {
        $params{reviewers} = $CodestrikerTest::Config::email_adddress[1];
    }
     
    unless ( exists($params{topic_file}) )
    {
        $params{topic_file} = 'newtopic.t';
    }

    my $newTopic = $self->GetNewTopicPage();

    ok( $newTopic , "get new topic page");

    my $confirmPage = $newTopic->CreateNewTopic( %params );

    ok( $confirmPage->TopicCreated(),"test topic created" );

    # refresh
    ok( $self->Get(),"refresh main page to get link to the new topic");

    my $topic_content = $self->GetLink($params{topic_title});

    ok( $topic_content,"get topic content page");

    return $topic_content;
}

# Returns the number of 
sub GetNumberOfTopics
{
    my ($self) = @_;

    $self->_ParseTopicList();

    return scalar( @{$self->{topic_list}} );
}

# Returns the topic hash, in the order they appeard in the window.
sub GetTopics
{
    my ($self) = @_;

    $self->_ParseTopicList();

    return @{$self->{topic_list}};
}

sub GetNewTopicPage
{
    my ($self) = @_;

    my $newtopicpage = $self->GetLink("Create new topic");
    
    ok( $newtopicpage->Get(),"get new topic page from main page" );

    return $newtopicpage;
}

# state the state of one of more topics on the main page. Pass in the 
# new topic state, and the index's of the topics that you want to 
# change.
sub ChangeTopicStates
{
    my ($self,$new_state, @indexs) = @_;

    my @forms = @{$self->{forms}};

    is( scalar(@forms) ,1,"make sure we only have one form in the main page");
     
    my ($form) = @forms;

    foreach my $index (@indexs)
    {
        my $input = $form->find_input( "selected_topics", "checkbox", $index );

        $input->check();
    }

    $form->param( topic_state=>$new_state );

    #$form->dump();

    ok( $self->GetFromRequest($form->click()), "make sure ChangeTopicStates is good");
}

# Private function to parse the topic table, and return each topic info as a hash reference.
sub _ParseTopicList
{
    my ($self) = @_;

    if ( !exists($self->{topic_list}))
    {
	my $content = $self->{response}->content;

	my $p = HTML::TokeParser->new(doc=>\$content);

	$p->get_tag("table");
	$p->get_tag("/table");

	# This is the topic table.

	my @topics;
	my @headers;

	while ($p->get_tag("tr")) 
	{	
	    if ( scalar(@topics) == 0)
	    {
		# Parse the header.
		
		my $header = "";

		do
		{
		    $p->get_tag("th");
		    $header = $p->get_trimmed_text("/th");
		    push( @headers, $header);

		    # print "# $header\n";
		}
		while($header ne "State");

		$p->get_tag("/th");		
	    }

	    $p->get_tag("/td");

	    $p->get_tag("td");
	    my $title = $p->get_trimmed_text("/td");

	    $p->get_tag("td");
	    my $author = $p->get_trimmed_text("/td");

	    $p->get_tag("td");
	    my $reviewers = $p->get_trimmed_text("/td");

	    $p->get_tag("td");
	    my $cc = $p->get_trimmed_text("/td");

	    $p->get_tag("td");
	    my $date_string = $p->get_trimmed_text("/td");

	    my $state ="";
	    my $bugid = "";

	    if ( @headers == 6)
	    {
		$p->get_tag("td");
		$state = $p->get_trimmed_text("/td");
	    }
	    else
	    {
		$p->get_tag("td");
		$bugid = $p->get_trimmed_text("/td");

		$p->get_tag("td");
		$state = $p->get_trimmed_text("/td");
	    }

	    if ( $author ne "")
	    {
		# Parse the Date out - format is "20:55:59 Thu, 6 Nov, 2003"

		my ($hour,$min,$sec,$dayname,$day,$month,$year) = 
		    $date_string =~ /(\d+):(\d+):(\d+) ([a-zA-Z]+), (\d+) ([a-zA-Z]+), (\d+)$/;

		# print "# $date_string = $hour,$min,$sec,$dayname,$day,$month,$year\n";

		my @date = ($year,Date::Calc::Decode_Month($month),$day, $hour,$min,$sec);

		my $topic = 
		{
		    title=>$title,
		    author=>$author,
		    reviewers=>$reviewers,
		    cc=>$cc,
		    datestring=>$date_string,
		    state=>$state,
		    date=>\@date,
		    bugid=>$bugid
		};

		foreach my $key (sort keys %$topic)
		{
		    # print $key . "=>" . $topic->{$key} . ",";
		}

		# print "\n";
		
		push (@topics,$topic);
	    }
	}

	$self->{topic_list} = \@topics;
    }

}

1;

