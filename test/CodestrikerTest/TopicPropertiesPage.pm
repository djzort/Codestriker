
package CodestrikerTest::TopicPropertiesPage;

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

sub SetTopicProperties
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
        if ( $options{$key} ne $form->value( $key ) ) 
        {
        $form->value($key,$options{$key});
    }
    }

    #$form->dump();

    return $self->GetFromRequest($form->click());
}

sub GetTopicProperties
{
    my ($self) = @_;

    $self->_ParsePageHTML();

    my @forms = @{$self->{forms}};

    is( scalar(@forms) ,1, "make sure the new topic page has one form");
     
    my ($form) = @forms;

    my %properties;

    $properties{topic_title} = $form->value('topic_title');

    $properties{topic_title} = $form->value('topic_title');
    $properties{topic_description} = $form->value('topic_description');
    $properties{repository} = $form->value('repository');
    $properties{projectid} = $form->value('projectid');
    $properties{author} = $form->value('author');
    $properties{reviewers} = $form->value('reviewers');
    $properties{cc} = $form->value('cc');
    $properties{topic_state} = $form->value('topic_state');

    return %properties;
}

sub CompareProperties
{
    my ($self,%properties) = @_;

    my %actualProperties = $self->GetTopicProperties();

    foreach my $key (keys %properties)
    {
        if (!exists $actualProperties{$key})
        {
            print "# key $key does not exist\n";
            return 0;
        }
        else
        {
            my $actual = $actualProperties{$key};
            my $prop = $properties{$key};

            # Make sure we compare email address in sorted order with all spaces removed
            # so that we don't fail a test because of the codestriker transformations.
            if ( $key eq "author" || $key eq "reviewers" || $key eq "cc")
            {
                $actual =~ s/ //g;
                $prop =~ s/ //g;

                $prop = join ',', sort split /[,;]/,$prop;
                $actual = join ',', sort split /[,;]/,$actual;
            }

            if ( $prop ne $actual)
            {
                print "# key $key \"$actual\" ne \"$prop\"\n";
                return 0;
            }
        }
    }

    return 1;
}

