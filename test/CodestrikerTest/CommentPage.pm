package CodestrikerTest::CommentPage;

use strict;
use warnings;

use Test::More;
use LWP::UserAgent;

use CodestrikerTest::Page;

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
#   repository
#   projecid
#   author
#   reviewers
#   cc
#   topic_state

sub AddComment
{
    my ($self,%options) = @_;

    $self->_ParsePageHTML();

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

    return $self->GetFromRequest($form->click());
}


1;
