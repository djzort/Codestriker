
package CodestrikerTest::NewTopicPage;

use strict;
use warnings;

use Test::More;
use LWP::UserAgent;

use CodestrikerTest::Page;
use CodestrikerTest::NewTopicPageConfirm;

our @ISA = 'CodestrikerTest::Page';

sub new
{
    my ($class,$url) = @_;

    my $self = CodestrikerTest::Page::new($class,$url);

    return $self;

}

# pass in the form paramters as a hash
#   topic_title
#   topic_description
#   topic_file
#   start_tag
#   end_tag
#   module
#   repository
#   projecid
#   email
#   reviewers
#   cc

# Return Confirm page 

sub CreateNewTopic
{
    my ($self,%options) = @_;

    $self->Get();

    my @forms = @{$self->{forms}};

    is( scalar(@forms) ,1, "make sure the new topic page has one form");
     
    my ($form) = @forms;

    #$form->dump();

    # The dumb form module does not like getting all of its params passed in at once.
    foreach my $key ( keys ( %options ))
    {
        $form->value($key,$options{$key});
    }

    #$form->dump();

    my $confirmPage = CodestrikerTest::NewTopicPageConfirm->new();

    $confirmPage->GetFromRequest($form->click());

    return $confirmPage;
}


1;


