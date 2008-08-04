# Tests to ensure that hg diffs (Mercurial SCM) are handled correctly.

use strict;
use Fatal qw / open close /;
use Test::More tests => 6;

use lib '../../lib';
use Codestriker;
use Codestriker::FileParser::PatchUnidiff;

# Parse the test hg patch file.
my $fh;
open( $fh, '<', '../../test/testtopictexts/hg-diff1.txt' );
my @deltas = Codestriker::FileParser::PatchUnidiff->parse($fh);
close($fh);

# Set what the expected output should be.
my @expected;
push @expected, make_delta(
	filename       => 'b/addedtest.txt',
	old_linenumber => 0,
	new_linenumber => 1,
	revision => $Codestriker::ADDED_REVISION,
	text => <<'END_DELTA',
+Lorem ipsum dolor sit amet, consectetuer 
+adipiscing elit. Sed laoreet erat vel arcu. Vestibulum 
+ante ipsum primis in faucibus orci luctus et ultrices posuere 
+cubilia Curae; Aliquam et diam ac nisi congue semper. Nulla 
+consequat. Cras molestie dictum turpis. Aenean lorem diam, 
+luctus at, tempus ac, semper ut, lorem. Nulla consequat, velit
+eu tincidunt commodo, diam lorem sodales leo, vitae aliquet leo 
+leo eget eros. Vestibulum consectetuer iaculis pede. 
+Suspendisse potenti. Sed non magna. Donec vel augue. 
+Sed iaculis nisi sed nunc. Sed cursus tellus eu risus. 
+Ut eros quam, imperdiet et, ultricies non, iaculis at, sem. 
+Donec et lacus in massa aliquet pretium. Suspendisse lacus. 
+Vestibulum ante ipsum primis in faucib
+us orci luctus et ultrices posuere cubilia Curae;
END_DELTA
);

push @expected, make_delta(
	filename       => 'a/deletetest.txt',
	old_linenumber => 1,
	new_linenumber => 0,
	revision => $Codestriker::REMOVED_REVISION,
	text => <<'END_DELTA',
-Class aptent taciti sociosqu ad litora torquent 
-per conubia nostra, per inceptos himenaeos. 
-Aliquam auctor. Proin tempor commodo nisl. 
END_DELTA
);

push @expected, make_delta(
	filename       => 'b/feedback.html',
	old_linenumber => 10,
	new_linenumber => 10,
	text => <<'END_DELTA',
   }
   div.modalFeedback h1{
       margin: 20px 20px 20px 20px;
-      font-size: 18pt;
   }
    #feedbackForm textarea {
       font-family: Arial,Helvetica,sans-serif;
END_DELTA
);

push @expected, make_delta(
	filename       => 'b/feedback.html',
	old_linenumber => 23,
	new_linenumber => 22,
	text => <<'END_DELTA',
     border: solid 3px #ddddFF;
     padding: 3px;
     width: 50px;
+    height: 50px;
   }
   #feedbackForm input#feedback_email{
    width: 60%;
END_DELTA
);

push @expected, make_delta(
	filename       => 'b/feedback.html',
	old_linenumber => 31,
	new_linenumber => 31,
	text => <<'END_DELTA',
 </head>
 <body>
 
-Hello from hg
+Hello to codestriker from hg
 
 </body>
 </html>
END_DELTA
);

# Check that the extracted deltas match what is expected.
is( @deltas, @expected, "Number of deltas in hg diff 1" );
for ( my $index = 0; $index < @deltas; $index++ ) {
	is_deeply( $deltas[$index], $expected[$index],
		"Delta $index in hg diff 1" );
}

# Convenience function for creating a delta object.
sub make_delta {

	# Set constant properties for all git deltas.
	my $delta = {};
	$delta->{binary}   = 0;
	$delta->{repmatch} = 0;
	$delta->{revision} = $Codestriker::PATCH_REVISION;
	$delta->{description} = '';

	# Apply the passed in arguments.
	my %arg = @_;
	$delta->{filename}       = $arg{filename};
	$delta->{old_linenumber} = $arg{old_linenumber};
	$delta->{new_linenumber} = $arg{new_linenumber};
	$delta->{text}           = $arg{text};
	$delta->{revision}       = $arg{revision} if exists $arg{revision};

	return $delta;
}
