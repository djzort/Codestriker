
package CodestrikerTest::SearchPage;

use strict;
use warnings;

use Test::More;
use LWP::UserAgent;

use CodestrikerTest::Page;
use CodestrikerTest::MainPage;

our @ISA = 'CodestrikerTest::Page';

sub new
{
    my ($class,$url) = @_;

    my $self = CodestrikerTest::Page::new($class,$url);

    return $self;

}

# pass in the form paramters as a hash
#  sauthor
#  sreviewer
#  scc
#  state_group
#  project_group
#  stext
#  text_group
# Return Confirm page 

sub SubmiteSearch
{
    my ($self,%options) = @_;

    $self->Get();

    my @forms = @{$self->{forms}};

    is( scalar(@forms) ,1,"make sure we only have one form in the page");
     
    my ($form) = @forms;

    #$form->dump();

    # The dumb form module does not like getting all of its params passed in at once.
    foreach my $key ( keys ( %options ))
    {
        $form->param($key,$options{$key});
    }

    #$form->dump();

    my $ua = LWP::UserAgent->new;


    my $response = $ua->request($form->click());

    my $resultPage = CodestrikerTest::MainPage->new("");

    $resultPage->GetFromRequest($form->click()); 

    return $resultPage;
}


1;


