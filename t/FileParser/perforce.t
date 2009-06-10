# Tests to ensure that perforce patches are handled correctly.

use strict;
use Fatal qw / open close /;
use Test::More tests => 6;
use Test::Differences;

use lib '../../lib';
use Codestriker;
use Codestriker::FileParser::Parser;

# Parse the test perforce describe file.
my $fh;
open( $fh, '<', '../../test/testtopictexts/perforce-diff14.txt' );
my @deltas = Codestriker::FileParser::Parser->parse($fh, 'text/plain',
                                                   undef, 111, undef);
close($fh);

# Set what the expected output should be.
my @expected;
push @expected, make_delta(
	filename       => '//depot/autobuild/Build.pm',
	revision       => '12',
	old_linenumber => '499',
	new_linenumber => '499',
	text => <<'END_DELTA',
   
     if ($state eq "start") {
       print SENDMAIL "\t\tBuild started for release $rel. Build log could be found at:\n";
-      print SENDMAIL "http://172.20.1.120/build_log/$bldlog\n";
+      print SENDMAIL "http://172.20.1.251/build_log/$bldlog\n";
       print SENDMAIL "\n You would be notified once build is done.\n";
       print SENDMAIL "\n\n\nHappy Building... :)";
     }
END_DELTA
);

push @expected, make_delta(
	filename       => '//depot/autobuild/Build.pm',
	revision       => '12',
	old_linenumber => '507',
	new_linenumber => '507',
	text => <<'END_DELTA',
 
       print SENDMAIL "\t\tBuild for release $rel finished successfully. Here is details:\n";
       print SENDMAIL "\nImage location: $stage_rel_link\n";
-      print SENDMAIL "Alternate location: http://172.20.1.120/images/$stage_rel_dir\n";
-      print SENDMAIL "Build Log: http://172.20.1.120/build_log/$bldlog\n";
-      print SENDMAIL "Sync Log: http://172.20.1.120/synclog/$synclog\n";
+      print SENDMAIL "Alternate location: http://172.20.1.251/images/$stage_rel_dir\n";
+      print SENDMAIL "Build Log: http://172.20.1.251/build_log/$bldlog\n";
+      print SENDMAIL "Sync Log: http://172.20.1.251/synclog/$synclog\n";
     }
     elsif ($state eq "failed") {

END_DELTA
);

push @expected, make_delta(
	filename       => '//depot/autobuild/Build.pm',
	revision       => '12',
	old_linenumber => '519',
	new_linenumber => '519',
	text => <<'END_DELTA',
       push (@error_msgs, @error_msg);
       print SENDMAIL "\n @error_msgs\n";
       print SENDMAIL "\n\nSee build log for full details: ";
-      print SENDMAIL "Build Log: http://172.20.1.120/build_log/$bldlog\n";
-      print SENDMAIL "Sync Log: http://172.20.1.120/synclog/$synclog\n";
+      print SENDMAIL "Build Log: http://172.20.1.251/build_log/$bldlog\n";
+      print SENDMAIL "Sync Log: http://172.20.1.251/synclog/$synclog\n";
       print SENDMAIL "\nPlease fix the issue and resubmit the build request.";
     }
     close (SENDMAIL);
END_DELTA
);

push @expected, make_delta(
	filename       => '//depot/autobuild/buildserver.pl',
	revision       => '3',
	old_linenumber => '10',
	new_linenumber => '10',
	text => <<'END_DELTA',
 my $syncdir = "/opt/LOG/synclog";
 my $stage_dir = "/mars/UPLOAD/BUILD/AUTO_BUILD/";
 my $stage_linkdir = '\\\\mars\\Remote\\UPLOAD\\BUILD\\AUTO_BUILD\\';
+my $db_stage_linkdir = '\\\\\\\\mars\\\\Remote\\\\UPLOAD\\\\BUILD\\\\AUTO_BUILD\\\\';
 my $image_dir = "/opt/Build/IMAGES/";
 my $script_dir = "/var/www/cgi-bin/build/BUILD_SCRIPTS/";
 my $buildlog_dir = "/opt/LOG/BUILD_LOG/";
END_DELTA
);

push @expected, make_delta(
	filename       => '//depot/autobuild/buildserver.pl',
	revision       => '3',
	old_linenumber => '282',
	new_linenumber => '283',
	text => <<'END_DELTA',
    	my $alt_stage_dir = $prod_rel[0] . "/" . $rel;
 	my $stage_rel_link = $stage_linkdir . "$prod_rel[0]" . "\\" . "$prod_rel[1]" . "\\" . "$rel";	
 	Build->build_status_mail($bld_usr,$rel,$log_name,"pass", $stage_rel_link, $alt_stage_dir);
+
+	my $db_stage_rel_link = $db_stage_linkdir . "$prod_rel[0]" . "\\\\" . "$prod_rel[1]" . "\\\\" . "$rel";
+	my $stage_int_sql = "UPDATE releases SET internal_stage=\'$db_stage_rel_link\'
+				where releases.release=\'$rel\'";
+	Build->run_sql_query($stage_int_sql, ";");
+
       }
     }
     else {
END_DELTA
);

# Check that the extracted deltas match what is expected.
is( @deltas, @expected, "Number of deltas in perforce patch 1" );
for ( my $index = 0; $index < @deltas; $index++ ) {
	eq_or_diff( $deltas[$index], $expected[$index],
		        "Delta $index in perforce patch 1" );
}

open( $fh, '<', '../../test/testtopictexts/perforce-diff15.txt' );
@deltas = Codestriker::FileParser::Parser->parse($fh, 'text/plain',
                                                 undef, 111, undef);
close($fh);

# Set what the expected output should be.
@expected = ();
push @expected, make_delta(
	filename       => '//seine/current/src/mods/stub_drv/indus_stub.c',
	revision       => '1',
	old_linenumber => '22',
	new_linenumber => '23',
	text => <<'END_DELTA',
//COMMENT SPECIFICALLY ADDED TO TEST CODESTRIKER
END_DELTA
);

push @expected, make_delta(
	filename       => '//seine/current/src/mods/stub_drv/indus_stub.c',
	revision       => '1',
	old_linenumber => '31',
	new_linenumber => '33',
	text => <<'END_DELTA',
//COMMENT SPECIFICALLY ADDED TO TEST CODESTRIKER
END_DELTA
);

# Check that the extracted deltas match what is expected.
is( @deltas, @expected, "Number of deltas in perforce patch 2" );
for ( my $index = 0; $index < @deltas; $index++ ) {
	eq_or_diff( $deltas[$index], $expected[$index],
		        "Delta $index in perforce patch 2" );
}

# Convenience function for creating a delta object.
sub make_delta {

	# Set constant properties for all git deltas.
	my $delta = {};
	$delta->{binary}   = 0;
	$delta->{repmatch} = 1;
	$delta->{description} = '';

	# Apply the passed in arguments.
	my %arg = @_;
	$delta->{filename}       = $arg{filename};
	$delta->{old_linenumber} = $arg{old_linenumber};
	$delta->{new_linenumber} = $arg{new_linenumber};
	$delta->{text}           = $arg{text};
	$delta->{revision}       = $arg{revision};

	return $delta;
}
