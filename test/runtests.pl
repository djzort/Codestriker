
use strict;
use warnings;

use Test::Harness;

$ENV{CSTEST_OPTIONS} = join(' ',@ARGV);

#my @test_files = <*.t>;

my @test_files = qw( 
    mainpage.t
    htmlescape.t
    newtopic.t
    deletetopic.t
    mainpagechangestate.t
    changetopicproperties.t
    lintpages.t
    addcomments.t
    cleanuptesttopics.t
    );

runtests(@test_files);

exit(0);
