# Tests to ensure that subversion patches are handled correctly.

use strict;
use Fatal qw / open close /;
use Test::More tests => 36;
use Test::Differences;

use lib '../../lib';
use Codestriker;
use Codestriker::FileParser::SubversionDiff;

assert_delta_equals('../../test/testtopictexts/svn-Propdiff1.txt', ());
assert_delta_equals('../../test/testtopictexts/svn-Propdiff2.txt', ());
assert_delta_equals('../../test/testtopictexts/svn-Propdiff3.txt', ());
assert_delta_equals('../../test/testtopictexts/svn-Propdiff4.txt',
    make_delta(filename => 'parseBuildLogs',
			   old_linenumber => '9',
			   new_linenumber => '9',
	           revision => '7',
	           text => <<'END_DELTA',
     if [[ "${MYHOSTNAME}" == "compaq" ]]; then
         DATABASEHOST="elmo";
         XMLDIR="$HOME/downloads/cruise-xml"
-    else
-        DATABASEHOST="webdev2";
-        XMLDIR="/export/home/buildmaster/cruisecontrol/logs"
-    fi
 fi
 
 if [ -x "/usr/bin/python2" ]; then
END_DELTA
    ),
    make_delta(filename => 'buildCleanup.py',
			   old_linenumber => '28',
			   new_linenumber => '28',
	           revision => '7',
	           text => <<'END_DELTA',
 #    GCOMDirectories = ['/usr/local/apache2/htdocs/docs', '/export/home/buildmaster/cruisecontrol/GCOM']
 #    EPRODirectories = ['/usr/local/apache2/htdocs/docs', '/export/home/buildmaster/cruisecontrol/EPRODATA']
 
-    GCOMDirectories = [ 'testdata/branches/GCOM' ]
-    EPRODirectories = [ 'testdata/branches/EPRODATA' ]
     
-    activeGraingerBuild = database.getActiveBuild("PRD", "gcom")
-    activeEPROBuild = database.getActiveBuild("PRD", "eprodata")
 
     print activeGraingerBuild.getBranchIdentifier()
     print activeEPROBuild.getBranchIdentifier()
END_DELTA
    ));
   
assert_delta_equals('../../test/testtopictexts/svn-Propdiff5.txt',
    make_delta(filename => 'parseBuildLogs',
			   old_linenumber => '9',
			   new_linenumber => '9',
	           revision => '6',
	           text => <<'END_DELTA',
     if [[ "${MYHOSTNAME}" == "compaq" ]]; then
         DATABASEHOST="elmo";
         XMLDIR="$HOME/downloads/cruise-xml"
-    else
-        DATABASEHOST="webdev2";
-        XMLDIR="/export/home/buildmaster/cruisecontrol/logs"
-    fi
 fi
 
 if [ -x "/usr/bin/python2" ]; then
END_DELTA
    ),
    make_delta(filename => 'buildCleanup.py',
			   old_linenumber => '28',
			   new_linenumber => '28',
	           revision => '6',
	           text => <<'END_DELTA',
 #    GCOMDirectories = ['/usr/local/apache2/htdocs/docs', '/export/home/buildmaster/cruisecontrol/GCOM']
 #    EPRODirectories = ['/usr/local/apache2/htdocs/docs', '/export/home/buildmaster/cruisecontrol/EPRODATA']
 
-    GCOMDirectories = [ 'testdata/branches/GCOM' ]
-    EPRODirectories = [ 'testdata/branches/EPRODATA' ]
     
-    activeGraingerBuild = database.getActiveBuild("PRD", "gcom")
-    activeEPROBuild = database.getActiveBuild("PRD", "eprodata")
 
     print activeGraingerBuild.getBranchIdentifier()
     print activeEPROBuild.getBranchIdentifier()
END_DELTA
    ));
    
assert_delta_equals('../../test/testtopictexts/svn-Propdiff6.txt',
    make_delta(filename => 'parseBuildLogs',
			   old_linenumber => '9',
			   new_linenumber => '9',
	           revision => '6',
	           text => <<'END_DELTA',
     if [[ "${MYHOSTNAME}" == "compaq" ]]; then
         DATABASEHOST="elmo";
         XMLDIR="$HOME/downloads/cruise-xml"
-    else
-        DATABASEHOST="webdev2";
-        XMLDIR="/export/home/buildmaster/cruisecontrol/logs"
-    fi
 fi
 
 if [ -x "/usr/bin/python2" ]; then
END_DELTA
    ),
    make_delta(filename => 'buildCleanup.py',
			   old_linenumber => '28',
			   new_linenumber => '28',
	           revision => '6',
	           text => <<'END_DELTA',
 #    GCOMDirectories = ['/usr/local/apache2/htdocs/docs', '/export/home/buildmaster/cruisecontrol/GCOM']
 #    EPRODirectories = ['/usr/local/apache2/htdocs/docs', '/export/home/buildmaster/cruisecontrol/EPRODATA']
 
-    GCOMDirectories = [ 'testdata/branches/GCOM' ]
-    EPRODirectories = [ 'testdata/branches/EPRODATA' ]
     
-    activeGraingerBuild = database.getActiveBuild("PRD", "gcom")
-    activeEPROBuild = database.getActiveBuild("PRD", "eprodata")
 
     print activeGraingerBuild.getBranchIdentifier()
     print activeEPROBuild.getBranchIdentifier()
END_DELTA
    ));
    
assert_delta_equals('../../test/testtopictexts/svn-Propdiff7.txt',
    make_delta(filename => 'users/clechasseur/local/devsetup/CoveoDevSetup.iss',
			   old_linenumber => '31',
			   new_linenumber => '31',
	           revision => '44307',
	           text => <<'END_DELTA',
 
 [Languages]
 Name: english; MessagesFile: compiler:Default.isl
+; woo!
END_DELTA
));

assert_delta_equals('../../test/testtopictexts/svn-Propdiff8.txt',
    make_delta(filename => 'users/clechasseur/local/devsetup/CoveoDevSetup.iss',
			   old_linenumber => '31',
			   new_linenumber => '31',
	           revision => '44309',
	           text => <<'END_DELTA',
 
 [Languages]
 Name: english; MessagesFile: compiler:Default.isl
+; woo!
END_DELTA
));

assert_delta_equals('../../test/testtopictexts/svn-Propdiff9.txt',
    make_delta(filename => 'product/lib/javamail/mail.jar',
			   old_linenumber => -1,
			   new_linenumber => -1,
	           revision => '1.0',
	           text => '',
	           binary => 1),
    make_delta(filename => 'buildCleanup.py',
			   old_linenumber => '28',
			   new_linenumber => '28',
	           revision => '7',
	           text => <<'END_DELTA',
 #    GCOMDirectories = ['/usr/local/apache2/htdocs/docs', '/export/home/buildmaster/cruisecontrol/GCOM']
 #    EPRODirectories = ['/usr/local/apache2/htdocs/docs', '/export/home/buildmaster/cruisecontrol/EPRODATA']
 
-    GCOMDirectories = [ 'testdata/branches/GCOM' ]
-    EPRODirectories = [ 'testdata/branches/EPRODATA' ]
     
-    activeGraingerBuild = database.getActiveBuild("PRD", "gcom")
-    activeEPROBuild = database.getActiveBuild("PRD", "eprodata")
 
     print activeGraingerBuild.getBranchIdentifier()
     print activeEPROBuild.getBranchIdentifier()
END_DELTA
    ));


assert_delta_equals('../../test/testtopictexts/svn-look-diff1.txt',
    make_delta(filename => 't1.txt',
	           old_linenumber => '0',
	           new_linenumber => '1',
	           revision => '0',
	           text => <<'END_DELTA',
+line1
+line2
+line3
END_DELTA
));

assert_delta_equals('../../test/testtopictexts/svn-look-diff2.txt',
    make_delta(filename => 't1.txt',
	           old_linenumber => '1',
	           new_linenumber => '1',
	           revision => '89',
	           text => <<'END_DELTA',
+line0
 line1
 line2
+line2.2
 line3
END_DELTA
));

assert_delta_equals('../../test/testtopictexts/svn-look-diff3.txt',
    make_delta(filename => 't1.txt',
	           old_linenumber => '1',
	           new_linenumber => '0',
	           revision => '90',
	           text => <<'END_DELTA',
-line0
-line1
-line2
-line2.2
-line3
END_DELTA
));

assert_delta_equals('../../test/testtopictexts/svn-look-diff4.txt',
    make_delta(filename => 't1.txt',
	           old_linenumber => '1',
	           new_linenumber => '1',
	           revision => '92',
	           text => <<'END_DELTA',
-l1
+l1
+l2
+l3
END_DELTA
    ),
    make_delta(filename => 't2.txt',
	           old_linenumber => '1',
	           new_linenumber => '0',
	           revision => '92',
	           text => <<'END_DELTA',
-l1
END_DELTA
));    

assert_delta_equals('../../test/testtopictexts/svn-look-diff5.txt',
    make_delta(filename => 'show_user_photo.jpg',
	           old_linenumber => -1,
	           new_linenumber => -1,
	           text => '',
	           binary => 1,
	           revision => $Codestriker::PATCH_REVISION
    ),
    make_delta(filename => 't2.txt',
	           old_linenumber => '0',
	           new_linenumber => '1',
	           revision => '93',
	           text => <<'END_DELTA',
+aaa
+bbb
+ccc
END_DELTA
));    

assert_delta_equals('../../test/testtopictexts/svn-look-diff6.txt',
    make_delta(filename => 'show_user_photo.jpg',
	           old_linenumber => -1,
	           new_linenumber => -1,
	           text => '',
	           binary => 1,
	           revision => $Codestriker::REMOVED_REVISION
    ),
    make_delta(filename => 't1.txt',
	           old_linenumber => '1',
	           new_linenumber => '1',
	           revision => '94',
	           text => <<'END_DELTA',
 l1
+l11
 l2
+l22
 l3
END_DELTA
    ),
    make_delta(filename => 't2.txt',
	           old_linenumber => '1',
	           new_linenumber => '0',
	           revision => '94',
	           text => <<'END_DELTA',
-aaa
-bbb
-ccc
END_DELTA
    ),
    make_delta(filename => 't3.txt',
	           old_linenumber => '0',
	           new_linenumber => '1',
	           revision => '0',
	           text => <<'END_DELTA',
+labuda
END_DELTA
));    

# Convenience function for creating a delta object.
sub make_delta {

	# Set constant properties for all subversion deltas.
	my $delta = {};
	$delta->{binary}   = 0;
	$delta->{repmatch} = 1;
	$delta->{description} = '';

	# Apply the passed in arguments.
	my %arg = @_;
	$delta->{filename}       = $arg{filename};
	$delta->{revision}       = $arg{revision};
	$delta->{old_linenumber} = $arg{old_linenumber};
	$delta->{new_linenumber} = $arg{new_linenumber};
	$delta->{text}           = $arg{text};
	$delta->{binary}         = $arg{binary} if exists $arg{binary};

	return $delta;
}

# Function for parsing the topic text, and check that the parsed deltas
# matched the expected deltas.
sub assert_delta_equals {
	my $filename = shift;
	my @expected = @_;
	
	# Open up the specified file and attempt to parse the deltas
	# from it.
	my $fh;
	open( $fh, '<', $filename );
	my @actual = Codestriker::FileParser::SubversionDiff->parse($fh);
	close($fh);

	# Check that the extracted deltas match what is expected.
	is( @actual, @expected, "Number of deltas for file: $filename" );
	for ( my $index = 0; $index < @actual; $index++ ) {
		eq_or_diff( $actual[$index], $expected[$index],
			        "Delta $index in file $filename" );
    }
}