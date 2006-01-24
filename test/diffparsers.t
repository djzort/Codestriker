
# make sure if we don't have any repo configured that all traces of repo's 
# are gone from the system.

use strict;
use warnings;

use Test::More qw(no_plan);

use CodestrikerTest::Config;
use CodestrikerTest::MainPage;
use CodestrikerTest::Page;
use CodestrikerTest::PageFactory;
use CodestrikerTest::Util;

CodestrikerTest::Config::ProcessCommandLine();

my $main = CodestrikerTest::PageFactory->CreatePage($CodestrikerTest::Config::main_url);

my @filenames = <testtopictexts/*.txt>;

foreach my $filename (@filenames)
{
    my $repo = 'Local CVS';

    $filename =~ /\/([a-zA-Z]+)/;

    my $repo_type = $1;

    if ($repo_type eq "cvs")
    {
        $repo = 'Local CVS';
    } 
    elsif ($repo_type eq "perforce")
    {
        $repo = 'perforce:sits:sits2@localhost:1666';
    }
    elsif ($repo_type eq "clearcase")
    {
        $repo = 'clearcase:c:\\stuff\\view_name\\vob_name';
    }
    elsif ($repo_type eq "svn")
    {
        $repo = 'svn:http://svn.collab.net/repos/svn/trunk';
    }
    elsif ($repo_type eq "vss")
    {
        $repo = 'vss:c:\\Program Files\\Microsoft Visual Studio\\VSS;admin;password';
    }

    print "# Creating topic for file $filename - $repo_type - $repo\n";
    
    my $topic_content = $main->MakeAndNavigateToNewTopic(topic_file=>$filename,repository=>$repo);

    # clean it up.
    my $properties = $topic_content->GetLink('Topic Properties');

    my @files = $topic_content->GetTopcFileInfo();
    my @bench_files = ();
    
    if ( -e "$filename.bench" )
    {
        open BENCH,"<$filename.bench" or die "$!";

        my $index = 0;
        
        while ( <BENCH> )
        {
            chop;
            my ($sourcefilename,$version,$added,$removed) = split /\t/;

            is( $sourcefilename,$files[$index]->{filename},
                "$filename $index - $sourcefilename == $files[$index]->{filename}" );
            is( $version,$files[$index]->{version}, 
                "$filename $index - $version == $files[$index]->{version}" );
            is( $added,$files[$index]->{added_lines},
                "$filename $index - $added == $files[$index]->{added_lines}" );
            is( $removed,$files[$index]->{removed_lines},
                "$filename $index - $removed == $files[$index]->{removed_lines}" );

            ++$index;
        }
        
        close(BENCH);
    }
    else
    {
        print "# *** creating $filename.bench\n";

        open BENCH,">$filename.bench" or die "$!";

        my $index = 0;
        foreach my $file (@files)
        {
            print BENCH $files[$index]->{filename} . "\t" . 
                        $files[$index]->{version} . "\t" . 
                        $files[$index]->{added_lines} . "\t" . 
                        $files[$index]->{removed_lines} . "\n"; 

            ++$index;
        }

        close BENCH;
    }

    ok( $properties->SetTopicProperties( topic_state=>'Deleted'),"change delete");
}




0;

