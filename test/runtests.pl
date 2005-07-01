
use strict;
use warnings;

use Test::Harness;

$ENV{CSTEST_OPTIONS} = join(' ',@ARGV);

my @test_files = <*.t>;

verify_installed_modules();

# make sure that cleanuptesttopics.t runs last
@test_files = sort 
    { 
    return 1 if ( $a eq 'cleanuptesttopics.t');
    return -1  if ( $b eq 'cleanuptesttopics.t');

    $a cmp $b;
    }  @test_files;


runtests(@test_files);

exit(0);


sub verify_installed_modules
{
    # Indicate which modules are required for codestriker (this code is
    # completely stolen more-or-less verbatim from Bugzilla)
    my $modules = [ 
        { name => 'Test', version => '1.25' }, 
        { name => 'Test::Harness', version => '2.46' }, 
        { name => 'Test::More', version => '0.47' }, 
        { name => 'LWP::UserAgent', version => '2.024' }, 
        { name => 'Getopt::Long', version => '2.25' }, 
        { name => 'File::Copy', version => '2.03' }, 
        { name => 'Date::Calc', version => '5.3' }, 
        { name => 'HTML::TokeParser', version => '2.30' }, 
        { name => 'HTML::Form', version => '1.049' }, 
        { name => 'HTML::LinkExtractor', version => '0.13' }, 
        { name => 'HTML::Lint', version => '1.28' }, 
        { name => 'Compress::Zlib', version => '1.33' }
    ];

    my $problem = 0;
    foreach my $module (@{$modules}) {
        if ( have_vers($module->{name}, $module->{version}) == 0) {
            $problem = 1;
        }
    }

    if ( $problem ) {
        die "tests stopped, Missing modules\n";
    }

}

# This was originally clipped from the libnet Makefile.PL, adapted here to
# use the above vers_cmp routine for accurate version checking.
sub have_vers {
  my ($pkg, $wanted) = @_;
  my ($msg, $vnum, $vstr);
  no strict 'refs';

  eval { my $p; ($p = $pkg . ".pm") =~ s!::!/!g; require $p; };

  $vnum = ${"${pkg}::VERSION"} || ${"${pkg}::Version"} || 0;
  $vnum = -1 if $@;

  if ($vnum eq "-1") { # string compare just in case it's non-numeric
        $vstr = "it is not installed";
  }
  elsif (vers_cmp($vnum,"0") > -1) {
    $vstr = "version v$vnum is installed";
  }
  else {
    $vstr = "unknown";
  }

  my $vok = (vers_cmp($vnum,$wanted) > -1);

  if (!$vok) {
    printf("Module %15s needs v%s, however %s.\n",$pkg,$wanted,$vstr);
  }

  return $vok;
}


# vers_cmp is adapted from Sort::Versions 1.3 1996/07/11 13:37:00 kjahds,
# which is not included with Perl by default, hence the need to copy it here.
# Seems silly to require it when this is the only place we need it...
sub vers_cmp {
  if (@_ < 2) { die "not enough parameters for vers_cmp" }
  if (@_ > 2) { die "too many parameters for vers_cmp" }
  my ($a, $b) = @_;
  my (@A) = ($a =~ /(\.|\d+|[^\.\d]+)/g);
  my (@B) = ($b =~ /(\.|\d+|[^\.\d]+)/g);
  my ($A,$B);
  while (@A and @B) {
    $A = shift @A;
    $B = shift @B;
    if ($A eq "." and $B eq ".") {
      next;
    } elsif ( $A eq "." ) {
      return -1;
    } elsif ( $B eq "." ) {
      return 1;
    } elsif ($A =~ /^\d+$/ and $B =~ /^\d+$/) {
      return $A <=> $B if $A <=> $B;
    } else {
      $A = uc $A;
      $B = uc $B;
      return $A cmp $B if $A cmp $B;
    }
  }
  @A <=> @B;
}
