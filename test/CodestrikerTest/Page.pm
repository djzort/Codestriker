
package CodestrikerTest::Page;

use strict;
use warnings;

use LWP::UserAgent;
use HTML::Form;
use HTML::LinkExtractor;
use CodestrikerTest::PageFactory;
use HTML::Lint;
use Test::More;
use Compress::Zlib;

sub new
{
    my ($class,$url) = @_;

    my $self = {};

    $self->{url} = $url;

    bless $self,$class;

    return $self;
}



# fetches the url that the page object was created with.
sub Get
{
    my ($self) = @_;

    my $request = HTTP::Request->new(GET => $self->{url}); 

    return $self->GetFromRequest( $request );
}

# Does a get, but wants a HTTP::Request object passed in rather than using
# the url in the self object.
sub GetFromRequest
{
    my ($self,$request) = @_;

    delete $self->{links};
    delete $self->{forms};

    # need to test the compression config.
    $request->header('Accept-Encoding','gzip');

    my $ua = LWP::UserAgent->new;

    # tell LWP that it is ok to be redirected after a post command, as is done
    # with search page.
    push @{ $ua->requests_redirectable }, 'POST';  

    $self->{response} = $ua->request($request);

    # uncompress it if it was sent compressed.
    if ( defined($self->{response}) && $self->IsCompressed() )
    {
        $self->{response}->content(
            Compress::Zlib::memGunzip($self->{response}->content));
    }

    if ($self->{response}->is_success)
    {

        $self->_ParsePageHTML();
    }
    else
    {
	my ($pack,$file,$line,$sub) = caller(0);
	print "# " . $sub . " $self->{url} " . $self->{response}->status_line . "\n";
    }

    return $self->{response}->is_success;
}


# Creates a new page object from the supplied link name. The name that is passed in 
# is the user visable part.
sub GetLink
{
    my ($self,$linkname) = @_;

    $self->_ParsePageHTML();

    my $new_page;

    foreach my $link ( @{$self->{links}} )
    {
	if ( defined $link->{_TEXT})
	{
	    $link->{_TEXT} =~ />([^<]*)<\/[aA]>/;
	    my $matched_linkname = $1;

            $matched_linkname = HTML::Entities::decode($matched_linkname);

            $matched_linkname =~ s/  / /;

            #print "# $matched_linkname == $linkname\n";

	    if ( defined $matched_linkname && $linkname eq $matched_linkname)
	    {
		$new_page = CodestrikerTest::PageFactory->CreatePage( $link->{href} );
                last;
	    }
	}
    }

    return $new_page;
}

# runs HTML::Lint over the page.
sub LintPageHTML
{
    my ($self,$linkname) = @_;
    my $lint = HTML::Lint->new(only_types => HTML::Lint::Error::STRUCTURE);

    my $content = $self->{response}->content;

    $lint->parse( $content );

    my $count = 0;
    foreach my $error ( $lint->errors ) {
        print "# " . $error->as_string, "\n";
	$count += 1;
    }

    return $count;
}

# Returns the title bar title of the page.
sub GetTitle
{
    my ($self) = @_;

    my $content = $self->{response}->content;

    my $p = HTML::TokeParser->new(doc=>\$content);

    my $title = "";
    if ($p->get_tag("title")) 
    {
	$title = $p->get_trimmed_text;
    }
    
    return $title;    
}

# crawles all of the links in the page, and vefifies that they can load.
sub VerifyLinks
{
    my ($self,$linkname) = @_;

    $self->_ParsePageHTML();

    my $bad_links = 1;

    foreach my $link ( @{$self->{links}} )
    {
        print "# get page $link->{href}\n";
	my $new_page = CodestrikerTest::Page->new( $link->{href} );

	if ( $link->{href} =~ /javascript:alert/ == 0 && $new_page->Get() == 0)
	{
            return 0;
	}
    }

    return $bad_links;
}

sub DumpLinks
{
    my ($self) = @_;

    $self->_ParsePageHTML();

    print "# DumpLinks for $self->{url}\n";

    foreach my $link ( @{$self->{links}} )
    {
	$link->{_TEXT} =~ />([^<]*)<\/[aA]>/;
	my $matched_linkname = $1;
	
	if (defined ($matched_linkname) )
	{
	    print "#   $matched_linkname\n";
	}
	else
	{
	    # print "#   match failed ... " . $link->{_TEXT} . "\n";
	}
    }
}

# Returns the content of the page
sub GetPageContent
{
    my ($self) = @_;

    $self->_ParsePageHTML();

    $self->{response}->content;
}

# returns the collection of link objects. The link objects are hashes
# with keys for _TEXT , and href;
sub GetLinks
{
    my ($self) = @_;

    $self->_ParsePageHTML();

    return @{$self->{links}};
}

# Private function to parse the links and forms from the page.
sub _ParsePageHTML
{
    my ($self) = @_;

    if ( !exists( $self->{response} ) )
    {
        ok( $self->Get(),"get page $self->{url} from _ParsePageHTML");
    }

    if ( ! exists( $self->{links} ) )
    { 

	my $content = $self->{response}->content;

        if ( $self->{response}->content_type eq 'text/html' )
        {
	    my $links = HTML::LinkExtractor->new();

	    $links->parse(\$content);

            my @alllinks = @{$links->links()};
            my @links;

            foreach my $link (@alllinks)
            {
                if ( defined ( $link->{_TEXT} ))
                {
	            $link->{_TEXT} =~ />([^<]*)<\/[aA]>/;
	            my $matched_linkname = $1;

                    if ( defined($matched_linkname) && 
                         $matched_linkname eq 'Help' && 
                         $CodestrikerTest::Config::check_help_links == 0)
                    {
                        # don't crawl into the online help, just eat any link called "Help".
                    }
                    elsif ( $link->{href} =~ /javascript:/ == 0)
                    {
                        push @links,$link;
                    }                
                }
            }
	    
	    $self->{links} = \@links;
        }
    }

    if ( ! exists( $self->{forms} ) )
    {
        if ( $self->{response}->content_type eq 'text/html')
        {
	    my $content = $self->{response}->content;
	    my @forms = HTML::Form->parse($content,$self->{response}->base);

	    $self->{forms} = \@forms;
        }
        else
        {
            $self->{forms} = [];
        }
    }

}

# returns true if the page was returned compressed.
sub IsCompressed
{
    my ($self) = @_;

    if ( !exists( $self->{response} ) )
    {
        ok( $self->Get(),"get page $self->{url} from IsCompressed");
    }

    my $encoding = $self->{response}->header( 'Content-Encoding');
    
    # uncompress it if it was sent compressed.
    return defined($encoding) && $encoding eq 'x-gzip';
}


1;