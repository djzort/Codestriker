
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

sub GetTopcFileInfo
{
    my ($self) = @_;

    $self->_ParseFileList();

    return @{$self->{file_list}};

}

sub _ParseFileList
{
    my ($self) = @_;

    if ( !exists($self->{file_list}))
    {
	my $content = $self->{response}->content;

	my $p = HTML::TokeParser->new(doc=>\$content);

	$p->get_tag("table");
	$p->get_tag("table");
	$p->get_tag("table");
	$p->get_tag("/table");

	# This is the topic table.
    
        $p->get_tag("/tr"); # move past the TOC header.

	my @files;

	while (my $token = $p->get_tag("tr","/table")) 
	{
            last if $token->[0] eq "/table";

	    $token = $p->get_tag("td");
        
            my $hasVersion = !exists( $token->[1]->{"colspan"} );

	    my $filename = $p->get_trimmed_text("/td");
            $filename =~ s/^\[Jump to\] //;

            my $version = "";
            if ( $hasVersion)
            {
	        $p->get_tag("td");
	        $version = $p->get_trimmed_text("/td");

                # trim the white space, the \xA0 is a html character code for a space.
                $version =~ s/^[\s\xA0]+//g;
                $version =~ s/[\s\xA0]+$//g;
            }

	    $p->get_tag("td");
	    my $added_removed_lines = $p->get_trimmed_text("/td");
            $added_removed_lines =~ /\+([0-9]+),-([0-9]+)/;

            my $added_lines = "";
            my $removed_lines = "";
            if ( defined($1) && defined($2))
            {
                $added_lines = $1;
                $removed_lines = $2;
            }

	    my $file = 
	    {
		filename=>$filename,
                version=>$version,
                added_lines=>$added_lines,
                removed_lines=>$removed_lines
	    };

            # for debugging.
            # print "# " . scalar(@files) . " fn=$filename v=$version add=$added_lines remove=$removed_lines\n";

	    push (@files,$file);
	}

	$self->{file_list} = \@files;
    }
}


1;

