
package CodestrikerTest::Config;

use strict;
use warnings;

use Getopt::Long;
use File::Copy;

our $main_url;
our @email_adddress;
our $title;
our $run_quick;
our $check_help_links;
our $codestriker_config_file;

sub RestoreDefaultConfiguration
{
    if ( -f "codestriker.conf" )
    {
        copy("codestriker.conf",$codestriker_config_file) or die "$!";
    }
    else
    {
        copy($codestriker_config_file,"codestriker.conf") or die "$!";
    }
}

BEGIN
{
    $run_quick = 0;
    $check_help_links = 0;

    open CONFIG_FILE,"<runtests.conf" or die "can't open config files runtests.conf $!";

    # slurp up the config file, then eval it.

    my @lines = <CONFIG_FILE>;

    my $file = join("",@lines);

    eval $file;
    die $@ if $@;

    close CONFIG_FILE;

    # Restore the default config file that is stored in the current directory.
    RestoreDefaultConfiguration();
}


sub ProcessCommandLine
{
    if ( $ENV{CSTEST_OPTIONS} )
    {
        push @ARGV, split /\s/,$ENV{CSTEST_OPTIONS};
    }

    my $results = GetOptions (
        "quick"             => \$run_quick,
        "check_help_links"  => \$check_help_links
        );

    if ( $results == 0 || scalar( @ARGV ) )
    {
        print "error: bad command line options\n";
        exit(0);
    }
}



1;

