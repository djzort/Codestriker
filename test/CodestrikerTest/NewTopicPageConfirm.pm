
package CodestrikerTest::NewTopicPageConfirm;

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

# Returns true if the topic was really created.
sub TopicCreated
{
    my ($self) = @_;

    my $content = $self->{response}->content;

    return $content =~ /Topic created/ && $content =~ /Topic URL/;    
}

1;


