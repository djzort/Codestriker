
use strict;
use warnings;

use Test::Harness;

$ENV{CSTEST_OPTIONS} = join(' ',@ARGV);

my @test_files = <*.t>;

# make sure that cleanuptesttopics.t runs last
@test_files = sort 
    { 
    return 1 if ( $a eq 'cleanuptesttopics.t');
    return -1  if ( $b eq 'cleanuptesttopics.t');

    $a cmp $b;
    }  @test_files;


runtests(@test_files);

exit(0);
