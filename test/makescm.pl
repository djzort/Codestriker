use strict;
use warnings;

use Cwd;

my $scm_base = "scm";
my $scm_repo_dir = "$scm_base/repositories";
my $scm_working_dir = "$scm_base/working";

my $subversion_repo = "$scm_repo_dir/subversion";
my $subversion_working = "$scm_working_dir/subversion";

my $subversion_repo_url = "file://" . cwd() . "/$subversion_repo";

# Clean everything up
if ( -e $scm_base)
{
    system("rm -rf $scm_base") and die "$!";
}

system("mkdir $scm_base") and die "$!";
system("mkdir $scm_repo_dir") and die "$!";
system("mkdir $scm_working_dir") and die "$!";
system("mkdir $subversion_working") and die "$!";

system("svnadmin create $subversion_repo") and die "$!";

system("svn checkout $subversion_repo_url $subversion_working") and die "$!";

my @testfile;

for (my $i = 0; $i < 10; ++$i)
{
    push (@testfile,"line $i");
}

open (FILE,">$subversion_working/test1.c") or die "$!";
print FILE join("\n",@testfile);
close FILE;

system("mkdir $subversion_working/dir") and die "$!";

open (FILE,">$subversion_working/dir/test2.c") or die "$!";
print FILE join("\n",@testfile);
close FILE;

system("svn add $subversion_working/test1.c") and die "$!";
system("svn add $subversion_working/dir") and die "$!";

system("svn commit -m \"first rev\" $subversion_working") and die "$!";

splice @testfile,3,1;
splice @testfile,5,0,"new line";

splice @testfile,7,1,"new line2";

open (FILE,">$subversion_working/test1.c") or die "$!";
print FILE join("\n",@testfile);
close FILE;

system("svn commit -m \"second rev\" $subversion_working") and die "$!";

open (FILE,">$subversion_working/dir/test2.c") or die "$!";
print FILE join("\n",@testfile);
close FILE;

system("svn commit -m \"third rev\" $subversion_working") and die "$!";



