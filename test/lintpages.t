
use strict;
use warnings;

use Test::More qw(no_plan);

use CodestrikerTest::Config;
use CodestrikerTest::MainPage;
use CodestrikerTest::Page;
use CodestrikerTest::PageFactory;
use CodestrikerTest::Util;

CodestrikerTest::Config::ProcessCommandLine();

# crawl every page in codestriker and make sure the HTML passes lint and that 
# all of the links work.

my %links;

$links{$CodestrikerTest::Config::main_url} = 0;

my $links_left_to_check = 1;

my $levels = 0;
my $max_levels = 10000;

if ( $CodestrikerTest::Config::run_quick )
{
    $max_levels = 1;
}

while ($links_left_to_check && $max_levels > $levels )
{
    ++$levels;

    $links_left_to_check = 0;

    foreach my $link ( sort keys %links)
    {
        if ( $links{$link} == 0)
        {
            # make sure we don't lint it twice.
            $links{$link} = 1;

            my $page = CodestrikerTest::PageFactory->CreatePage($link);

            my $get_status = $page->Get();

            ok( $get_status, "get page $link");

            if ( $get_status == 0)
            {
            


            }

            # we are not checkin links here, so don't fail it if a get fails.
            if ( $get_status && 
                 $page->{response}->content_type eq 'text/html' )
            {
                ok( $page->LintPageHTML() == 0,"lint page $link");

                foreach my $newLink ( $page->GetLinks() )
                {
                    my $newLinkBase = $newLink->{href};
                
                    # don't lint a page twice looking for local anchors. Chew off everything after the
                    # "#" in the url.
                    $newLinkBase =~ s/#[\S]+$//;

	            if ( defined $newLink->{_TEXT})
	            {
	                if ( exists $links{$newLinkBase} == 0)
	                {
                            $links{$newLinkBase} = 0;
	                }
	            }
                }
            }
                
            $links_left_to_check = 1;
        }
    }
}

0;