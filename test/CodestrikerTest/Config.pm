
package CodestrikerTest::Config;

use strict;
use warnings;

use Getopt::Long;
use File::Copy;

our $main_url;
our @email_adddress;
our $title;
our $version;
our $run_quick;
our $check_help_links;
our $codestriker_config_file;
our $codestriker_config_file_content;


sub RestoreDefaultConfiguration
{
    unlink($codestriker_config_file);
    $codestriker_config_file_content  = "";
}

sub SetConfigOption
{
    my ($option) = @_;

    open(FILE,">$codestriker_config_file") or die "$!";

    print FILE $option;

    close FILE;
}


sub ReloadConfiguration
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

    $title = "Codestriker $version";
}

# called at the start of each test. Used to process the command line args
# from runtests.pl and reset the config of codestriker.
sub ProcessCommandLine
{
    ReloadConfiguration();

    # Restore the default config file that is stored in the current directory.
    RestoreDefaultConfiguration();

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

