
package CodestrikerTest::TopicContentPage;

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

# Submits a comments for the given filename, line number, and old or new diff.
# returns the submit comment page.
sub GetSubmitCommentPage
{
    my ($self,$filenum,$line,$new) = @_;

    # because of the java script, we just need to bake in the URL.

    $self->{url} =~ /\?topic=([\d]+)/;

    my $topicid = $1;

    my $url = $CodestrikerTest::Config::main_url . 
              "?fn=$filenum" . 
              "&line=$line" .
              "&new=$new" .
              "&topic=$topicid" .
              "&action=edit" .
              "&a=$filenum|$line|$new";

    print "# $url\n";

    my $commentPage = CodestrikerTest::CommentPage->new($url);

    $commentPage->Get();

    return $commentPage;
}

# submites the entire comment, without dealing directly with the comment page.
sub SubmitComment
{
    my ($self,$filenum,$line,$new,$comment,$email,$cc) = @_;

    my $page = $self->GetSubmitCommentPage($filenum,$line,$new);

    $page->LintPageHTML();
    
    my %params;

    $params{comments} = $comment;
    
    if (defined($email))
    {
        $params{email} = $email;
    }
    
    if (defined($cc))
    {
        $params{cc} = $cc;
    }

    return $page->AddComment( %params );
}


# Returns the number of comments reported in the comment tab.
sub GetCommentCount
{
    my ($self) = @_;

    my $content = $self->{response}->content;

    ok( $content =~ /Topic Comments \(([0-9]+)\)/ ); 

    my $count = $1;

    return $count;
}


1;

