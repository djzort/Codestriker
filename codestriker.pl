#!/usr/bin/perl -wT

###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
# Version 1.4.4
#
# Codestriker is a perl CGI script which is used for performing code reviews
# in a collaborative fashion as opposed to using unstructured emails.
#
# Authors create code review topics, where the nominated reviewers will be
# automatically notified by email.  Reviewers then submit comments against
# the code on a per-line basis, and can also view comments submitted by the
# other reviewers as they are created.  Emails are sent to the appropriate
# parties when comments are created, as an alert mechanism.  The author is
# also free to submit comments against the review comments.
#
# Once all reviewers have finished, the author has all review comments
# available in a structured fashion, as opposed to a pile of unstructured
# emails.
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

require 5.000;

use strict;

use CGI qw/:standard :html3/;
use CGI::Carp 'fatalsToBrowser';

use FileHandle;

#use diagnostics -verbose;

use vars qw (
	     $datadir $sendmail $bugtracker $cvsviewer $cvsrep
	     $cvscmd $cvsaccess $codestriker_css
	     $default_topic_create_mode $background_col
	     $diff_background_col $default_tabwidth $use_compression
	     $gzip $config $NORMAL_MODE $COLOURED_MODE
	     $COLOURED_MONO_MODE @days @months $default_context
	     $email_context $email_hr $context_colour
	     $comment_line_colour $cookie_name $document_file
	     $comment_file $filetable_file @document $document_title
	     $document_bug_ids @document_description
	     $document_reviewers $document_cc $document_author
	     $document_creation_time %comment_exists
	     @comment_linenumber @comment_data @comment_author
	     @comment_date @filetable_filename @filetable_revision
	     @filetable_offset @cvs_filedata
	     $cvs_filedata_max_line_length $header_generated_record
	     $diff_current_filename @diff_new_lines
	     @diff_new_lines_numbers @diff_new_lines_offsets
	     @diff_old_lines @diff_old_lines_numbers
	     @diff_old_lines_offsets @view_file_minus @view_file_plus
	     @view_file_minus_offset @view_file_plus_offset
	     $ADDED_REVISION $REMOVED_REVISION $PATCH_REVISION
	     $OLD_FILE $NEW_FILE $BOTH_FILES $tabwidth
	     $output_compressed $url_prefix $query
	     );

# BEGIN CONFIGURATION OPTIONS --------------------

# Location of configuration file, which contains all of the other
# configuration options.
$config = "/var/www/codestriker/codestriker.conf";

# END OF CONFIGURATION OPTIONS --------------------

# Set the PATH to something sane.
$ENV{'PATH'} = "/bin:/usr/bin";

# Constants for viewing modes.
$NORMAL_MODE = 0;
$COLOURED_MODE = 1;
$COLOURED_MONO_MODE = 2;

# Day strings
@days = ("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
	 "Saturday");

# Month strings
@months = ("January", "Februrary", "March", "April", "May", "June", "July",
	   "August", "September", "October", "November", "December");

# Default context width for line-based reviews.
$default_context = 2;

# Default context width for email display.
$email_context = 8;

# Separator to use in email.
$email_hr = "--------------------------------------------------------------";

# Colour for the line of interest when displaying the context.
$context_colour = "red";

# Colour of line number if it has been commented on.
$comment_line_colour = "red";

# Cookie attributes to set.
$cookie_name = "codestriker_cookie";

# The name of the file which stores the document.
$document_file = "document";

# The name of the file which stores the comments.
$comment_file = "comments";

# The name of the file which stores the filetable.
$filetable_file = "filetable";

# The document data is stored as an array of strings, indexed by line number.
@document = ();

# The document title.
$document_title = "";

# The associated document bug number.
$document_bug_ids = "";

# The document description.
@document_description = ();

# The document reviewers.
$document_reviewers = "";

# The Cc list to be informed of the new topic.
$document_cc = "";

# The document author.
$document_author = "";

# When the document was created.
$document_creation_time = "";

# Indicates if a comment exists for a specific linenumber.
%comment_exists = ();

# Indexed by comment number.  Contains the line number the comment is about.
@comment_linenumber = ();

# Indexed by comment number.  Contains the comment data.
@comment_data = ();

# Indexed by comment number.  Contains the comment author.
@comment_author = ();

# Indexed by comment number.  Contains the comment date.
@comment_date = ();

# Indexed by filenumber.  Contains the name of the file.
@filetable_filename = ();

# Indexed by filenumber.  Contains the revision of the file.
@filetable_revision = ();

# Indexed by filenumber.  Contains the topic line number offset for the file.
@filetable_offset = ();

# The cvs document data read.
@cvs_filedata = ();

# The maximum line length of the CVS file.
$cvs_filedata_max_line_length = 0;

# Record if the HTML header has been generated yet or not.
$header_generated_record = 0;

# State variables for display_coloured_data.

# The current file being diffed.
$diff_current_filename = "";

# New lines within a diff block.
@diff_new_lines = ();

# The corresponding lines they refer to.
@diff_new_lines_numbers = ();

# The corresponding offsets they refer to.
@diff_new_lines_offsets = ();

# Old lines within a diff block.
@diff_old_lines = ();

# The corresponding lines they refer to.
@diff_old_lines_numbers = ();

# The corresponding offsets they refer to.
@diff_old_lines_offsets = ();

# A record of added and removed lines for a given diff block when displaying a
# file in a popup window, along with their offsets.
@view_file_minus = ();
@view_file_plus = ();
@view_file_minus_offset = ();
@view_file_plus_offset = ();

# Revision number constants used in the filetable with special meanings.
$ADDED_REVISION = "1.0";
$REMOVED_REVISION = "0.0";
$PATCH_REVISION = "0.1";

# New constants used for viewing files.
$OLD_FILE = 0;
$NEW_FILE = 1;
$BOTH_FILES = 2;

# The current tabwidth being used.
$tabwidth = $default_tabwidth;

# Indicates whether the output has been sent compressed.
$output_compressed = 0;

# Indicate what URL is prefixed before relative URLs.  For old
# netscapes (<= 4), we require the relative path to the script as well.
$url_prefix = "";

# The CGI query object.
$query = undef;

# Subroutine prototypes.
sub edit_topic($$$$$);
sub view_topic($$$);
sub download_topic_text($);
sub submit_comments($$$$$$);
sub create_topic();
sub submit_topic($$$$$$$$);
sub view_file($$$$);
sub error_return($);
sub display_context($$$);
sub myescapeHTML($);
sub read_document_file($$);
sub read_comment_file($);
sub read_filetable_file($);
sub read_cvs_file($$);
sub lock($);
sub unlock($);
sub get_email();
sub get_reviewers();
sub get_cc();
sub get_tabwidth();
sub get_mode();
sub tabadjust($$);
sub build_edit_url($$$$);
sub build_download_url($);
sub build_view_url($$$);
sub build_view_url_extended($$$$$$);
sub build_view_file_url($$$$$$);
sub build_create_topic_url();
sub generate_header($$$$$$$);
sub header_generated();
sub get_comment_digest($);
sub get_context($$$$);
sub untaint_digits($$);
sub untaint_filename($);
sub untaint_revision($);
sub untaint_email($);
sub untaint_emails($);
sub untaint_bug_ids($);
sub get_time_string($);
sub make_canonical_email_list($);
sub make_bug_list($);
sub display_data ($$$$$$$$$$$$$$);
sub display_coloured_data ($$$$$$$$$$$$$$$$$);
sub render_linenumber($$$$$$);
sub add_old_change($$$);
sub add_new_change($$$);
sub render_changes($$$);
sub render_inplace_changes($$$$$$$);
sub render_coloured_cell($);
sub normal_mode_start($);
sub normal_mode_finish($$);
sub coloured_mode_start($$);
sub coloured_mode_finish($$);
sub print_coloured_table();
sub get_file_linenumber ($$$$$);
sub cleanup();
sub main();

# Call main to kick things off.
main;

sub main() {
    # Retrieve the CGI parameters.
    $query = new CGI;
    my $topic = $query->param('topic');
    my $line = $query->param('line');
    my $context = $query->param('context');
    my $action = $query->param('action');
    my $comments = $query->param('comments');
    my $email = $query->param('email');
    my $topic_text = $query->param('topic_text');
    my $topic_title = $query->param('topic_title');
    my $topic_description = $query->param('topic_description');
    my $reviewers = $query->param('reviewers');
    my $cc = $query->param('cc');
    my $topic_text_fh = $query->upload('topic_file');
    my $revision = $query->param('revision');
    my $filename = $query->param('filename');
    my $linenumber = $query->param('linenumber');
    my $mode = $query->param('mode');
    my $bug_ids = $query->param('bug_ids');
    my $new = $query->param('new');
    $tabwidth = $query->param('tabwidth');

    # Load up the configuration file.
    if (-f $config) {
	do $config;
    } else {
	error_return("Couldn't find configuration file: \"$config\".\n<BR>" .
		     "Please fix the \$config setting in codestriker.pl.");
    }

    # Untaint the required input.
    $topic = untaint_digits($topic, 'topic');
    $email = untaint_email($email);
    $reviewers = untaint_emails($reviewers);
    $cc = untaint_emails($cc);
    $filename = untaint_filename($filename);
    $revision = untaint_revision($revision);
    $bug_ids = untaint_bug_ids($bug_ids);
    $new = untaint_digits($new, 'new');

    # Retrieve the tabwidth from the cookie if it is not specified in the URL.
    if (! defined($tabwidth) || ($tabwidth != 4 && $tabwidth != 8)) {
	$tabwidth = get_tabwidth();
    }

    # Retrieve the mode from the cookie if it is not specified in the URL.
    if (! defined $mode) {
	$mode = get_mode();
    }

    # Perform the action specified in the "action" parameter.
    # If the action is not specified, assume a new topic is to be created.
    if (! defined $action || $action eq "") {
	create_topic();
    }
    elsif ($action eq "edit") {
	edit_topic($line, $topic, $context, $email, $mode);
    }	
    elsif ($action eq "view") {
	view_topic($topic, $email, $mode);
    }
    elsif ($action eq "submit_comment") {
	submit_comments($line, $topic, $comments, $email, $cc, $mode);
    }
    elsif ($action eq "create") {
	create_topic();
    }
    elsif ($action eq "submit_topic") {
	submit_topic($topic_title, $email, $topic_text, $topic_description,
		     $reviewers, $cc, $topic_text_fh, $bug_ids);
    }
    elsif ($action eq "download") {
	download_topic_text($topic);
	return;
    }
    elsif ($action eq "view_file") {
	view_file($topic, $filename, $new, $mode);
    }
    else {
	create_topic();
    }

    print $query->end_html();
    cleanup();
    exit;
}

# Cleanup any open resources, so that this script can be re-used again
# within a mod_perl environment.
sub cleanup() {
    if ($output_compressed) {
	# Close the GZIP handle and remove the tie.
	select(STDOUT);
	close(GZIP);
	untie *GZIP;
	$output_compressed = 0;
    }

    # Close all of the other filehandles that might be open.  In most cases,
    # these will already be closed, but we do this to ensure there are no
    # file descriptor leaks.
    close DOCUMENT;
    close COMMENTS;
    close FILETABLE;
    close CVSFILE;
    close PATCH;
    close MAIL;
    close DIFF;
}

# Untaint $topic, which should be just a bunch of digits.
sub untaint_digits($$) {
    my ($value, $name) = @_;

    if (defined $value && $value ne "") {
	if ($value =~ /^(\d+)$/) {
	    return $1;
	} else {
	    error_return("Invalid parameter $name \"$value\" - " .
			 "you naughty boy.");
	}
    } else {
	return $value;
    }
}

# Untaint $filename, which should consist of a bunch of alphanumeric characters
# and some other innocent characters.
sub untaint_filename($) {
    my ($filename) = @_;

    if (defined $filename && $filename ne "") {
	if ($filename =~ /^([-_\/\@\w\.\s]+)$/) {
	    return $1;
	} else {
	    error_return("Invalid filename \"$filename\" - you naughty boy.");
	}
    } else {
	return $filename;
    }
}

# ntain revision, which should be a bunch of numbers separated by periods.
sub untaint_revision($) {
    my ($revision) = @_;

    if (defined $revision && $revision ne "") {
	if ($revision =~ /^([\d\.]+)$/) {
	    return $1;
	} else {
	    error_return("Invalid revision \"$revision\" - you naught boy.");
	}
    } else {
	return $revision;
    }
}
	    
# Untaint a single email address, which should be a regular email address.
sub untaint_email($) {
    my ($email) = @_;

    if (defined $email && $email ne "") {
	if ($email =~ /^([-_\@\w\.]+)$/) {
	    return $1;
	} else {
	    error_return("Invalid email \"$email\" - you naughty boy.");
	}
    } else {
	return $email;
    }
}

# Untaint a list of email addresses.
sub untaint_emails($) {
    my ($emails) = @_;

    if (defined $emails && $emails ne "") {
	if ($emails =~ /^([-_@\w,;\.\s]+)$/) {
	    return $1;
	} else {
	    error_return("Invalid email list \"$emails\" - you naughty boy.");
	}
    } else {
	return $emails;
    }
}

# Untaint a list of big ids.
sub untaint_bug_ids($) {
    my ($bug_ids) = @_;

    if (defined $bug_ids && $bug_ids ne "") {
	if ($bug_ids =~ /^([0-9A-Za-z_;,\s\n\t]+)$/) {
	    return $1;
	} else {
	    error_return("Invalid bug ids \"$bug_ids\" - you naught boy.");
	}
    } else {
	return $bug_ids;
    }
}

# Return true if the header has been generated already, false otherwise.
sub header_generated() {
    return ($header_generated_record != 0);
}

# Generate the HTTP header and start of the body.
sub generate_header($$$$$$$) {
    my ($topic, $topic_title, $email, $reviewers, $cc, $mode, $bg_colour) = @_;

    # Check if the header has already been generated (in the case of an error).
    return if (header_generated());
    $header_generated_record = 1;

    # Set the cookie in the HTTP header for the $email, $cc, $reviewers and
    # $tabwidth parameters.
    my %cookie_value; 
    if (defined $query->cookie("$cookie_name")) {
	%cookie_value = $query->cookie("$cookie_name");
    }

    $email = get_email() if (!defined $email || $email eq "");
    $reviewers = get_reviewers() if (!defined $reviewers || $reviewers eq "");
    $cc = get_cc() if (!defined $cc || $cc eq "");
    $tabwidth = get_tabwidth() if (!defined $tabwidth || $tabwidth eq "");
    $mode = get_mode() if (!defined $mode || $mode eq "");

    $cookie_value{'email'} = $email if $email ne "";
    $cookie_value{'reviewers'} = $reviewers if $reviewers ne "";
    $cookie_value{'cc'} = $cc if $cc ne "";
    $cookie_value{'tabwidth'} = $tabwidth if $tabwidth ne "";
    $cookie_value{'mode'} = $mode if $mode ne "";

    my $cookie_path = $query->url(-absolute=>1);
    my $cookie = $query->cookie(-name=>"$cookie_name",
				-expires=>'+10y',
				-path=>"$cookie_path",
				-value=>\%cookie_value);

    # This logic is taken from cvsweb.  There is _reason_ behind this logic...
    # Basically mozilla supports gzip regardless even though some versions
    # don't state this.  IE claims it does, but doesn't support it.  Using
    # the gzip binary technique doesn't work apparently under mod_perl.
    
    # Determine if the client browser is capable of handled compressed HTML.
    eval {
	require Compress::Zlib;
    };
    my $has_zlib = !$@;
    my $browser = $ENV{'HTTP_USER_AGENT'};

    # Determine what prefix is required for relative URLs.
    $url_prefix = ($browser =~ m%^Mozilla/(\d)% && $1 <= 4) ?
	$query->url(-relative=>1) : "";

    my $can_compress = ($use_compression &&
			((defined($ENV{'HTTP_ACCEPT_ENCODING'})
			  && $ENV{'HTTP_ACCEPT_ENCODING'} =~ m|gzip|)
			 || $browser =~ m%^Mozilla/3%)
			&& ($browser !~ m/MSIE/)
			&& !(defined($ENV{'MOD_PERL'}) && !$has_zlib));

    # Output the appropriate header if compression is allowed to the client.
    if ($can_compress &&
	($has_zlib || ($gzip ne "" && open(GZIP, "| $gzip -1 -c")))) {
	print $query->header(-cookie=>$cookie,
			     -content_encoding=>'x-gzip',
			     -vary=>'Accept-Encoding');

	# Flush header output, and switch STDOUT to GZIP.
	$| = 1; $| = 0;
	if ($has_zlib) {
	    tie *GZIP, __PACKAGE__, \*STDOUT;
	}
	select(GZIP);
	$output_compressed = 1;
    } else {
	print $query->header(-cookie=>$cookie);
    }

    my $title = "Codestriker";
    if (defined $topic_title && $topic_title ne "") {
	$title .= ": \"$topic_title\"";
    }
    print $query->start_html(-dtd=>'-//W3C//DTD HTML 3.2 Final//EN',
			     -charset=>'ISO-8859-1',
			     -title=>"$title",
			     -bgcolor=>"$bg_colour",
			     -style=>{src=>"$codestriker_css"},
			     -base=>$query->url(),
			     -link=>'blue',
			     -vlink=>'purple');

    # Write a comment indicating if this was compressed or not.
    print "\n<!-- Source was" . (!$output_compressed ? " not" : "") .
	" sent compressed. -->\n";

    # Write the simple open window javascript method for displaying popups.
    print <<EOF;
<SCRIPT LANGUAGE="JavaScript"><!--
 var windowHandle = '';

 function myOpen(url,name) {
     windowHandle = window.open(url,name,
				'toolbar=no,width=800,height=600,status=yes,scrollbars=yes,resizable=yes,menubar=no');
     if (windowHandle.opener == null) {
	 windowHandle.opener = self;
     }
     windowHandle.focus();
 }

    function fetch(url) {
	opener.location = url;
	opener.focus();
    }
 //-->
</SCRIPT>
EOF
}

# Return the time as a string.
sub get_time_string($) {
    my ($time_value) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime($time_value);
    $year += 1900;
    return sprintf("%02d:%02d:%02d $days[$wday], $mday $months[$mon], $year",
		   $hour, $min, $sec);
}

# Routine to convert text into an HTML version, but with hyperlinks rendered.
sub myescapeHTML($) {
    my ($text) = @_;

    # Split the text into words, and for any URL, convert it appropriately.
    my @words = split /([\s\n\t])/, $text;
    my $result = "";
    for (my $i = 0; $i <= $#words; $i++) {
	if ($words[$i] =~ /^([A-Za-z]+:\/\/.*[A-Za-z0-9_])(.*)$/o) {
	    # A URL, create a link to it.
	    $result .= $query->a({href=>$1}, $1) . CGI::escapeHTML($2);
	} else {
	    # Regular text, just escape it apprporiately and append it.
	    $result .= CGI::escapeHTML($words[$i]);
	}
    }

    return $result;
}
	
# Simple file locking routines.
sub lock ($) {
    my ($fh) = @_;

    flock $fh, 2;
    seek $fh, 0, 2;  # In case file is accessed while waiting for lock.
}

sub unlock ($) {
    my ($fh) = @_;
    
    flock $fh, 8;
}

# Report the error message, close off the HTML, and clean up any
# resources.
sub error_return ($) {
    my ($error_message) = @_;
    if (! header_generated()) {
	print $query->header, $query->start_html(-title=>'Codestriker error',
						 -bgcolor=>'white');
    }
    print $query->p, "<FONT COLOR='red'>$error_message</FONT>", $query->p;
    print "Press the \"back\" button, fix the problem and try again.";
    print $query->end_html();
    cleanup();
    exit;
}

# Read the topic's document file.
sub read_document_file($$) {
    my ($topic, $replace_tabs) = @_;

    if (! open(DOCUMENT, "$datadir/$topic/$document_file")) {
	error_return("Unable to open document file for topic \"$topic\": $!");
    }

    # Get the file's creation time.
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	$atime,$mtime,$ctime,$blksize,$blocks) = stat DOCUMENT;
    $document_creation_time = get_time_string($ctime);

    # Parse the document metadata.
    while (<DOCUMENT>) {
	my $data = $_;
	if ($data =~ /^Author: (.+)$/o) {
	    $document_author = $1;
	} elsif ($data =~ /^Title: (.+)$/o) {
	    $document_title = $1;
	} elsif ($data =~ /^Bug: (.*)$/o) {
	    $document_bug_ids = $1;
	} elsif ($data =~ /^Reviewers: (.+)$/o) {
	    $document_reviewers = $1;
	} elsif ($data =~ /^Cc: (.+)$/o) {
	    $document_cc = $1;
	} elsif ($data =~ /^Description: (\d+)$/o) {
	    my $description_length = $1;

	    # Read the document description.
	    @document_description = ();
	    for (my $i = 0; $i < $description_length; $i++) {
		my $data = <DOCUMENT>;
		chop $data;
		# Change tabs with spaces to preserve alignment during display.
		$data = tabadjust($data, 0) if ($replace_tabs);
		push @document_description, $data;
	    }
	} elsif ($data =~ /^Text$/) {
	    last;
	}
	# Silently ignore unknown fields.
    }
	    
    # Read the document data itself.
    @document = ();
    while (<DOCUMENT>) {
	chop;
	my $data = $_;

	# Replace tabs with spaces to preserve alignment during display.
	$data = tabadjust($data, 0) if ($replace_tabs);
	push @document, $data;
    }
    close DOCUMENT;
}

# Read the topic's comment file.
sub read_comment_file($) {
    my ($topic) = @_;

    if (! open(COMMENTS, "$datadir/$topic/$comment_file")) {
	error_return("Unable to open comment file for topic \"$topic\": $!");
    }

    %comment_exists = ();
    @comment_linenumber = ();
    @comment_data = ();
    @comment_author = ();
    @comment_date = ();
    while (<COMMENTS>) {
	# Read the metadata for the comment.
	/^(\d+) (\d+) ([-_\@\w\.]+) (.*)$/o;
	my $comment_size = $1;
	my $linenumber = $2;
	my $author = $3;
	my $datestring = $4;

	$comment_exists{$linenumber} = 1;
	push @comment_linenumber, $linenumber;
	push @comment_author, $author;
	push @comment_date, $datestring;
	my $comment_text = "";
	for (my $i = 0; $i < $comment_size; $i++) {
	    $comment_text .= <COMMENTS>;
	}
	push @comment_data, $comment_text;
    }
    close COMMENTS;
}

# Read the filetable metadata into memory.  Return 0 if there were problems
# reading the filetable.
sub read_filetable_file($) {
    my ($topic) = @_;

    if (! open (FILETABLE, "$datadir/$topic/$filetable_file")) {
	return 0;
    }

    my $rc = 1;
    for (my $i = 0; <FILETABLE>; $i++) {
	if (/\|(.*)\| ([\d\.]+) (\d+)$/o) {
	    $filetable_filename[$i] = $1;
	    $filetable_revision[$i] = $2;
	    $filetable_offset[$i] = $3;
	}
	else {
	    $rc = 0;
	    last;
	}
    }
    close FILETABLE;
    return $rc;
}

# Read the specified CVS file and revision into memory.
sub read_cvs_file ($$) {
    my ($filename, $revision) = @_;

    # Expand the CVS command, substituting in the revision and filename.
    my $command = eval "sprintf(\"$cvscmd\")";

    if (! open (CVSFILE, "$command 2>/dev/null |")) {
	error_return("Couldn't get CVS data for $filename $revision: $!");
    }

    $cvs_filedata_max_line_length = 0;
    for (my $i = 1; <CVSFILE>; $i++) {
	chop;
	$cvs_filedata[$i] = tabadjust($_, 0);
	my $line_length = length($cvs_filedata[$i]);
	if ($line_length > $cvs_filedata_max_line_length) {
	    $cvs_filedata_max_line_length = $line_length;
	}
    }
    close CVSFILE;
}

# Return the email address stored in the cookie.
sub get_email() {
    my %cookie = $query->cookie("$cookie_name");
    return (exists $cookie{'email'}) ? $cookie{'email'} : "";
}

# Return the reviewers stored in the cookie.
sub get_reviewers() {
    my %cookie = $query->cookie("$cookie_name");
    return (exists $cookie{'reviewers'}) ? $cookie{'reviewers'} : "";
}

# Return the Cc stored in the cookie.
sub get_cc() {
    my %cookie = $query->cookie("$cookie_name");
    return (exists $cookie{'cc'}) ? $cookie{'cc'} : "";
}

# Return the tabwidth stored in the cookie.
sub get_tabwidth() {
    my %cookie = $query->cookie("$cookie_name");
    if (exists $cookie{'tabwidth'}) {
	my $value = $cookie{'tabwidth'};
	return ($value != 4 && $value != 8) ? $default_tabwidth : $value;
    }
    else {
	return $default_tabwidth;
    }
}

# Return the tabwidth stored in the cookie.
sub get_mode() {
    my %cookie = $query->cookie("$cookie_name");
    return (exists $cookie{'mode'}) ? $cookie{'mode'} : $NORMAL_MODE;
}

# Retrieve the data that forms the "context" when submitting a comment.	
sub get_context ($$$$) {
    my ($line, $topic, $context, $html_view) = @_;

    # Get the minimum and maximum line numbers for this context, and return
    # the data.  The line of interest will be rendered appropriately.
    my $min_line = ($line - $context < 0 ? 0 : $line - $context);
    my $max_line = $line + $context;
    my $context_string = "";
    for (my $i = $min_line; $i <= $max_line && $i <= $#document; $i++) {
	my $linedata = $document[$i];
	if ($html_view) {
	    if ($i == $line) {
		$context_string .=
		    "<font color=\"$context_colour\">" .
		      CGI::escapeHTML($linedata) . "</font>\n";
	    } else {
		$context_string .= CGI::escapeHTML("$linedata") ."\n";
	    }
	} else {
	    $context_string .= ($i == $line) ? "* " : "  ";
	    $context_string .= $linedata . "\n";
	}
    }
    return $context_string;
}

# Replace the passed in string with the correct number of spaces, for
# alignment purposes.
sub tabadjust ($$) {
    my ($input, $htmlmode) = @_;

    $_ = $input;
    if ($htmlmode) {
	1 while s/\t+/'&nbsp' x (length($&) * $tabwidth - length($`) % $tabwidth)/e;
    }
    else {
	1 while s/\t+/' ' x (length($&) * $tabwidth - length($`) % $tabwidth)/e;
    }
    return $_;
}	

# Create the URL for viewing a topic with a specified tabwidth.
sub build_view_url_extended ($$$$$$) {
    my ($topic, $line, $mode, $tabwidth, $email, $prefix) = @_;
    return ($prefix ne "" ? $prefix : $url_prefix) .
	"?topic=$topic&action=view&mode=$mode" .
	((defined $tabwidth && $tabwidth ne "") ? "&tabwidth=$tabwidth" : "") .
	((defined $email && $email ne "") ? "&email=$email" : "") .
	($line != -1 ? "#${line}" : "");
}

# Create the URL for viewing a topic.
sub build_view_url ($$$) {
    my ($topic, $line, $mode) = @_;
    return build_view_url_extended($topic, $line, $mode, "", "", "");
}

# Create the URL for downloading the topic text.
sub build_download_url ($) {
    my ($topic) = @_;
    return $url_prefix . "?action=download&topic=$topic";
}

# Create the URL for creating a topic.
sub build_create_topic_url () {
    return $query->url() . "?action=create";
}	    

# Create the URL for editing a topic.
sub build_edit_url ($$$$) {
    my ($line, $topic, $context, $prefix) = @_;
    return ($prefix ne "" ? $prefix : $url_prefix) .
	"?line=$line&topic=$topic&action=edit" .
	    ((defined $context && $context ne "") ? "&context=$context" : "");
}

# Create the URL for viewing a new file.
sub build_view_file_url ($$$$$$) {
    my ($topic, $filename, $new, $line, $prefix, $mode) = @_;
    return $url_prefix . 
	"?action=view_file&filename=$filename&topic=$topic&mode=$mode&new=$new#"
	. "$prefix$line";
}

# Generate a string which represents a digest of all the comments made for a
# particular line number.  Used for "tool-tip" windows for line number links
# and/or setting the status bar.
sub get_comment_digest($) {
    my ($line) = @_;

    my $digest = "";
    if ($comment_exists{$line}) {
	for (my $i = 0; $i <= $#comment_linenumber; $i++) {
	    if ($comment_linenumber[$i] == $line) {
		# Need to remove the newlines for the data.
		my $data = $comment_data[$i];
		$data =~ s/\n/ /mg; # Remove newline characters

		if ($CGI::VERSION < 2.59) {
		    # Gggrrrr... the way escaping has been done between these
		    # versions has changed. This needs to be looked into more
		    # but this does the job for now as a workaround.
		    $data = CGI::escapeHTML($data);
		}
		$digest .= "$data ------- ";
	    }
	}
	# Chop off the last 9 characters.
	substr($digest, -9) = "";
    }
    
    return $digest;
}

# Download the topic text as "plain/text".
sub download_topic_text ($) {
    my ($topic) = @_;

    read_document_file($topic, 0);
    print $query->header(-type=>'text/plain');
    for (my $i = 0; $i <= $#document; $i++) {
	print "$document[$i]\n";
    }
}

# Add a comment to a specific line.
sub edit_topic ($$$$$) {
    my ($line, $topic, $context, $email, $mode) = @_;

    # If the $context is not set, set it to the default value.
    $context = $default_context if (!defined $context || $context eq "");

    # Read the document and comment file for this topic.
    read_document_file($topic, 1);
    read_comment_file($topic);

    # Display the header of this page.
    generate_header($topic, $document_title, $email, "", "", $mode,
		    $background_col);
    print $query->h2("Edit topic: $document_title");
    print $query->start_table();
    print $query->Tr($query->td("Author: "),
		     $query->td($document_author));
    print $query->Tr($query->td("Reviewers: "),
		     $query->td($document_reviewers));
    if (defined $document_cc && $document_cc ne "") {
	print $query->Tr($query->td("Cc: "),
			 $query->td($document_cc));
    }
    print $query->end_table();

    my $view_url = build_view_url($topic, $line, $mode);
    print $query->p, $query->a({href=>"$view_url"},"View topic");
    print $query->p, $query->hr, $query->p;

    # Display the context in question.  Allow the user to increase it
    # or decrease it appropriately.
    my $inc_context = ($context <= 0) ? 1 : $context*2;
    my $dec_context = ($context <= 0) ? 0 : int($context/2);
    my $inc_context_url = build_edit_url($line, $topic, $inc_context, "");
    my $dec_context_url = build_edit_url($line, $topic, $dec_context, "");
    print "Context: (" .
	$query->a({href=>"$inc_context_url"},"increase") . " | " .
	$query->a({href=>"$dec_context_url"},"decrease)");
    
    $query->p;
    print "<PRE>", get_context($line, $topic, $context, 1), "</PRE>",
          $query->p;

    # Display the comments which have been made for this line number
    # thus far in reverse order.
    for (my $i = $#comment_linenumber; $i >= 0; $i--) {
	if ($comment_linenumber[$i] == $line) {
	    print $query->hr, "$comment_author[$i] $comment_date[$i]";
	    print $query->br, "\n";
	    print $query->pre(myescapeHTML($comment_data[$i])), $query->p;
	}
    }
    
    # Create a form which will allow the user to enter in some comments.
    print $query->hr, $query->p("Enter comments:"), $query->p;

    print $query->start_form();
    $query->param(-name=>'action', -value=>'submit_comment');
    print $query->hidden(-name=>'action', -default=>'submit_comment');
    print $query->hidden(-name=>'line', -default=>"$line");
    print $query->hidden(-name=>'topic', -default=>"$topic");
    print $query->hidden(-name=>'mode', -default=>"$mode");
    print $query->textarea(-name=>'comments',
			   -rows=>15,
			   -columns=>75,
			   -wrap=>'hard');

    my $default_email = get_email();
    print $query->p, $query->start_table();
    print $query->Tr($query->td("Your email address: "),
		     $query->td($query->textfield(-name=>'email',
						  -size=>50,
						  -default=>"$default_email",
						  -override=>1,
						  -maxlength=>100)));
    print $query->Tr($query->td("Cc: "),
		     $query->td($query->textfield(-name=>'cc',
						  -size=>50,
						  -maxlength=>150)));
    print $query->end_table(), $query->p;
    print $query->submit(-value=>'submit');
    print $query->end_form();
}

# View the specified code review topic.
sub view_topic ($$$) {
    my ($topic, $email, $mode) = @_;

    read_document_file($topic, 1);
    read_comment_file($topic);

    # Display header information
    my $bg_colour =
	($mode == $NORMAL_MODE ? $background_col : $diff_background_col);
    generate_header($topic, $document_title, $email, "", "", $mode,
		    $bg_colour);

    my $create_topic_url = build_create_topic_url();
    print $query->a({href=>"$create_topic_url"}, "Create a new topic");
    print $query->p;

    my $escaped_title = CGI::escapeHTML($document_title);
    print $query->h2("$escaped_title"), "\n";

    print $query->start_table();
    print $query->Tr($query->td("Author: "),
		     $query->td($document_author)), "\n";
    print $query->Tr($query->td("Created: "),
		     $query->td($document_creation_time)), "\n";
    if ($document_bug_ids ne "") {
	my @bugs = split ' ', $document_bug_ids;
	my $bug_string = "";
	for (my $i = 0; $i <= $#bugs; $i++) {
	    $bug_string .= $query->a({href=>"$bugtracker$bugs[$i]"},
				     $bugs[$i]);
	    $bug_string .= ', ' unless ($i == $#bugs);
	}
	print $query->Tr($query->td("Bug IDs: "),
			 $query->td($bug_string));
    }
    print $query->Tr($query->td("Reviewers: "),
		     $query->td($document_reviewers)), "\n";
    if (defined $document_cc && $document_cc ne "") {
	print $query->Tr($query->td("Cc: "),
			 $query->td($document_cc)), "\n";
    }
    print $query->Tr($query->td("Number of lines: "),
		     $query->td($#document + 1)), "\n";
    print $query->end_table(), "\n";

    print "<PRE>\n";
    my $data = "";
    for (my $i = 0; $i <= $#document_description; $i++) {
	$data .= $document_description[$i] . "\n";
    }
    
    $data = myescapeHTML($data);

    # Replace occurances of bug strings with the appropriate links.
    if ($bugtracker ne "") {
	$data =~ s/(\b)([Bb][Uu][Gg]\s*(\d+))(\b)/$1<A HREF="${bugtracker}$3">$1$2$4<\/A>/mg;
    }
    print $data;
    print "</PRE>\n";

    my $number_comments = $#comment_linenumber + 1;
    my $url = build_view_url($topic, -1, $mode);
    if ($number_comments == 1) {
	print "Only one ", $query->a({href=>"${url}#comments"},
				     "comment");
	print " submitted.\n", $query->p;
    } elsif ($number_comments > 1) {
	print "$number_comments ", $query->a({href=>"${url}#comments"},
					     "comments");
	print " submitted.\n", $query->p;
    }

    my $download_url = build_download_url($topic);
    print $query->a({href=>"$download_url"},"Download"), " topic text.\n";

    print $query->p, $query->hr, $query->p;

    # Give the user the option of swapping between diff view modes.
    my $normal_url = build_view_url($topic, -1, $NORMAL_MODE);
    my $coloured_url = build_view_url($topic, -1, $COLOURED_MODE);
    my $coloured_mono_url = build_view_url($topic, -1, $COLOURED_MONO_MODE);
    if ($mode == $COLOURED_MODE) {
	print "View as (", $query->a({href=>$normal_url}, "plain"), " | ",
	$query->a({href=>$coloured_mono_url}, "coloured monospace"),
	") diff.\n";
    } elsif ($mode == $COLOURED_MONO_MODE) {
	print "View as (", $query->a({href=>$normal_url}, "plain"), " | ",
	$query->a({href=>$coloured_url}, "coloured variable-width"),
	") diff.\n";
    } else {
	print "View as (", $query->a({href=>$coloured_url},
				     "coloured variable-width"), " | ",
	$query->a({href=>$coloured_mono_url}, "coloured monospace"),
	") diff.\n";
    }
    print $query->br;

    # Display the option to change the tab width.
    my $newtabwidth = ($tabwidth == 4) ? 8 : 4;
    my $change_tabwidth_url;
    $change_tabwidth_url =
	build_view_url_extended($topic, -1, $mode, $newtabwidth, "", "");

    print "Tab width set to $tabwidth (";
    print $query->a({href=>"$change_tabwidth_url"},"change to $newtabwidth");
    print ")\n";

    print $query->p if ($mode == $NORMAL_MODE);

    # Number of characters the line number should take.
    my $max_digit_width = length($#document+1);

    # Record of the current CVS file being diffs (if the file is a
    # unidiff diff file).
    my $current_file = "";
    my $current_file_revision = "";
    my $current_old_file_linenumber = "";
    my $current_new_file_linenumber = "";
    my $diff_linenumbers_found = 0;
    my $reading_diff_block = 0;
    my $cvsmatch = 0;
    my $index_filename = "";
    my $block_description = "";

    # Display the data that is being reviewed.
    if ($mode == $COLOURED_MODE || $mode == $COLOURED_MONO_MODE) {
	coloured_mode_start($topic, $mode);
    } else {
	normal_mode_start($topic);
    }
    for (my $i = 0; $i <= $#document; $i++) {

	# Check for uni-diff information.
	if ($document[$i] =~ /^===================================================================$/) {
	    # The start of a diff block, reset all the variables.
	    $current_file = "";
	    $current_file_revision = "";
	    $current_old_file_linenumber = "";
	    $current_new_file_linenumber = "";
	    $block_description = "";
	    $reading_diff_block = 1;
	    $cvsmatch = 0;
	} elsif ($document[$i] =~ /^Index: (.*)$/o &&
		 ($mode == $COLOURED_MODE || $mode == $COLOURED_MONO_MODE)) {
	    $index_filename = $1;
	    next;
	} elsif ($document[$i] =~ /^\?/o &&
		 ($mode == $COLOURED_MODE || $mode == $COLOURED_MONO_MODE)) {
	    next;
	} elsif ($document[$i] =~ /^RCS file: ${cvsrep}\/(.*),v$/) {
	    # The part identifying the file.
	    $current_file = $1;
	    $cvsmatch = 1;
	} elsif ($document[$i] =~ /^RCS file:/o) {
	    # A new file (or a file that doesn't match CVS repository path).
	    $current_file = $index_filename;
	    $index_filename = "";
	    $cvsmatch = 0;
	} elsif ($document[$i] =~ /^retrieving revision (.*)$/o) {
	    # The part identifying the revision.
	    $current_file_revision = $1;
	} elsif ($document[$i] =~ /^diff/o && $reading_diff_block == 0) {
	    # The start for an ordinary patch file.
	    $current_file = "";
	    $current_file_revision = "";
	    $current_old_file_linenumber = "";
	    $current_new_file_linenumber = "";
	    $block_description = "";
	    $reading_diff_block = 1;
	    $cvsmatch = 0;
	} elsif ($document[$i] =~ /^\-\-\- (.*[^\s])\s+(Mon|Tue|Wed|Thu|Fri|Sat|Sun).*$/o &&
		 $current_file eq "") {
	    # This is likely to be an ordinary patch file - not a CVS one, in
	    # which case this is the start of the diff block.
	    $current_file = $1;
	    $index_filename = "";
	} elsif ($document[$i] =~ /^\@\@ \-(\d+),\d+ \+(\d+),\d+ \@\@(.*)$/o) {
	    # The part identifying the line number.
	    $current_old_file_linenumber = $1;
	    $current_new_file_linenumber = $2;
	    $block_description = $3;
	    $diff_linenumbers_found = 1;
	    $reading_diff_block = 0;
	}

	my $url = build_edit_url($i, $topic, "", "");

	# Display the data.
	if ($mode == $COLOURED_MODE || $mode == $COLOURED_MONO_MODE) {
	    display_coloured_data($i, $i, $i, 0, $max_digit_width,
				  $document[$i], $url, $current_file,
				  $current_file_revision,
				  $current_old_file_linenumber,
				  $current_new_file_linenumber,
				  $reading_diff_block,
				  $diff_linenumbers_found, $topic,
				  $mode, $cvsmatch,
				  $block_description);
	} else {
	    display_data($i, $max_digit_width, $document[$i], $url,
			 $current_file, $current_file_revision,
			 $current_old_file_linenumber,
			 $current_new_file_linenumber,
			 $reading_diff_block, $diff_linenumbers_found,
			 $topic, $mode, $cvsmatch,
			 $block_description);
	}

	# Reset the diff line numbers read, to handle the next diff block.
	if ($diff_linenumbers_found) {
	    $diff_linenumbers_found = 0;
	    $current_old_file_linenumber = "";
	    $current_new_file_linenumber = "";
	}
    }
    if ($mode == $COLOURED_MODE || $mode == $COLOURED_MONO_MODE) {
	coloured_mode_finish($topic, $mode);
    } else {
	normal_mode_finish($topic, $mode);
    }
    print $query->p;
    
    # Now display all comments in reverse order.  Put an anchor in for the
    # first comment.
    for (my $i = $#comment_linenumber; $i >= 0; $i--) {
	my $edit_url = build_edit_url($comment_linenumber[$i], $topic, "", "");
	if ($i == $#comment_linenumber) {
	    print $query->a({name=>"comments"},$query->hr);
	} else {
	    print $query->hr;
	}
	print $query->a({href=>"$edit_url"},
			"line $comment_linenumber[$i]"), ": ";
	print "$comment_author[$i] $comment_date[$i]", $query->br, "\n";
	print $query->pre(myescapeHTML($comment_data[$i])), $query->p;
    }
}

# Start topic view display hook for normal mode.
sub normal_mode_start ($) {
    my ($topic) = @_;
    print "<PRE>\n";
}

# Finish topic view display hook for normal mode.
sub normal_mode_finish ($$) {
    print "</PRE>\n";
}

# Start topic view display hook for coloured mode.  This displays a simple
# legend, displays the files involved in the review, and opens up the initial
# table.
sub coloured_mode_start ($$) {
    my ($topic, $mode) = @_;

    print $query->start_table({-cellspacing=>'0', -cellpadding=>'0',
			       -border=>'0'}), "\n";
    print $query->Tr($query->td("&nbsp;"), $query->td("&nbsp;"));
    print $query->Tr($query->td({-colspan=>'2'}, "Legend:"));
    print $query->Tr($query->td({-class=>'rf'},
				"Removed"),
		     $query->td({-class=>'rb'}, "&nbsp;"));
    print $query->Tr($query->td({-class=>'cf',
				 -align=>"center", -colspan=>'2'},
				"Changed"));
    print $query->Tr($query->td({-class=>'ab'}, "&nbsp;"),
		     $query->td({-class=>'af'},
				"Added"));
    print $query->end_table(), "\n";

    # Print out the "table of contents".  If the file table doesn't exist,
    # this could because we are reading an old code review.
    if (!read_filetable_file($topic)) {
	print_coloured_table();
	return;
    }

    print $query->p;
    print $query->start_table({-cellspacing=>'0', -cellpadding=>'0',
			       -border=>'0'}), "\n";
    print $query->Tr($query->td($query->a({name=>"contents"}, "Contents:")),
		     $query->td("&nbsp;")), "\n";
    for (my $i = 0; $i <= $#filetable_filename; $i++) {
	my $filename = $filetable_filename[$i];
	my $revision = $filetable_revision[$i];
	my $href_filename = build_view_url($topic, -1, $mode) . "#" . "$filename";
	my $class = "";
	$class = "af" if ($revision eq $ADDED_REVISION);
	$class = "rf" if ($revision eq $REMOVED_REVISION);
	$class = "cf" if ($revision eq $PATCH_REVISION);
	if ($revision eq $ADDED_REVISION ||
	    $revision eq $REMOVED_REVISION ||
	    $revision eq $PATCH_REVISION) {
	    # Added, removed or patch file.
	    print $query->Tr($query->td({-class=>"$class", -colspan=>'2'},
					$query->a({href=>"$href_filename"},
						  "$filename"))), "\n";
	} else {
	    # Modified file.
	    print $query->Tr($query->td({-class=>'cf'},
					$query->a({href=>"$href_filename"},
						  "$filename")),
			     $query->td({-class=>'cf'}, "&nbsp; $revision"),
			     "\n");
	}
    }
    print $query->end_table(), "\n";
    print_coloured_table();
}

# Render the initial start of the coloured table, with an empty row setting
# the widths.
sub print_coloured_table()
{
    print $query->start_table({-width=>'100%',
			       -border=>'0',
			       -cellspacing=>'0',
			       -cellpadding=>'0'}), "\n";
    print $query->Tr($query->td({-width=>'2%'}, "&nbsp;"),
		     $query->td({-width=>'48%'}, "&nbsp;"),
		     $query->td({-width=>'2%'}, "&nbsp;"),
		     $query->td({-width=>'48%'}, "&nbsp;"), "\n");
}


# Finish topic view display hook for coloured mode.
sub coloured_mode_finish ($$) {
    my ($topic, $mode) = @_;

    # Make sure the last diff block (if any) is written.
    render_changes($topic, $mode, 0);

    print "</TABLE>\n";
}

# Display a line for non-coloured data.
sub display_data ($$$$$$$$$$$$$$) {
    my ($line, $max_digit_width, $data, $edit_url, $current_file,
	$current_file_revision, $current_old_file_linenumber,
	$current_new_file_linenumber, $reading_diff_block,
	$diff_linenumbers_found, $topic, $mode, $cvsmatch,
	$block_description) = @_;

    # Escape the data.
    $data = CGI::escapeHTML($data);

    # Add the appropriate amount of spaces for alignment before rendering
    # the line number.
    my $digit_width = length($line);
    for (my $j = 0; $j < ($max_digit_width - $digit_width); $j++) {
	print " ";
    }
    print render_linenumber($line, $line, "", $topic, $mode, 0);

    # Now render the data.
    print " $data\n";
}

# Display a line for coloured data.  Note special handling is done for
# unidiff formatted text, to output it in the "coloured-diff" style.  This
# requires storing state when retrieving each line.
sub display_coloured_data ($$$$$$$$$$$$$$$$$) {
    my ($leftline, $rightline, $offset, $parallel, $max_digit_width,
	$data, $edit_url, $current_file, $current_file_revision,
	$current_old_file_linenumber, $current_new_file_linenumber,
	$reading_diff_block, $diff_linenumbers_found, $topic, $mode,
	$cvsmatch, $block_description) = @_;

    # Don't do anything if the diff block is still being read.  The upper
    # functions are storing the necessary data.
    return if ($reading_diff_block);

    # Escape the data.
    $data = CGI::escapeHTML($data);

    if ($diff_linenumbers_found) {
	if ($diff_current_filename ne $current_file) {
	    # The filename has changed, render the current diff block (if any)
	    # close the table, and open a new one.
	    render_changes($topic, $mode, $parallel);
	    print $query->end_table();

	    $diff_current_filename = $current_file;
	    print_coloured_table();

	    my $contents_url = build_view_url($topic, -1, $mode) . "#contents";
	    if ($cvsmatch) {
		# File matches something is CVS repository.  Link it to
		# the CVS viewer if it is defined.
		my $cell = "";
		my $revision_text = "revision $current_file_revision";
		if ($cvsviewer eq "") {
		    $cell = $query->td({-class=>'file', -colspan=>'3'},
				       "Diff for ",
				       $query->a({name=>"$current_file"},
						 "$current_file"),
				       "$revision_text");
		}
		else {
		    my $url = "$cvsviewer$current_file";
		    $cell = $query->td({-class=>'file', -colspan=>'3'},
				       "Diff for ",
				       $query->a({href=>"$url",
						  name=>"$current_file"},
						 "$current_file"),
				       "$revision_text");
		}
		print $query->Tr($cell,
				 $query->td({-class=>'file', align=>'right'},
					     $query->a({href=>$contents_url},
						       "[Go to Contents]")));
	    } else {
		# No match in repository - or a new file.
		print $query->Tr($query->td({-class=>'file', -colspan=>'3'},
					    "Diff for ",
					    $query->a({name=>"$current_file"},
						      "$current_file")),
				 $query->td({-class=>'file', align=>'right'},
					    $query->a({href=>$contents_url},
						      "[Go to contents]")));
	    }
	}

	print $query->Tr($query->td("&nbsp;"), $query->td("&nbsp;"),
			 $query->td("&nbsp;"), $query->td("&nbsp;"), "\n");

	# Output a diff block description if one is available, in a separate
	# row.
	if ($block_description ne "") {
	    my $description = CGI::escapeHTML($block_description);
	    print $query->Tr($query->td({-class=>'line', -colspan=>'2'},
					$description),
			     $query->td({-class=>'line', -colspan=>'2'},
					$description));
	}
	
	if ($cvsmatch && $cvsrep ne "") {
	    # Display the line numbers corresponding to the patch, with links
	    # to the CVS file.
	    my $url_old_full =
		build_view_file_url($topic, $current_file, $OLD_FILE,
				    $current_old_file_linenumber, "", $mode);
	    my $url_old = "javascript: myOpen('$url_old_full','CVS')";

	    my $url_old_both_full =
		build_view_file_url($topic, $current_file, $BOTH_FILES,
				    $current_old_file_linenumber, "L", $mode);
	    my $url_old_both =
		"javascript: myOpen('$url_old_both_full','CVS')";

	    my $url_new_full =
		build_view_file_url($topic, $current_file, $NEW_FILE,
				    $current_new_file_linenumber, "", $mode);
	    my $url_new = "javascript: myOpen('$url_new_full','CVS')";

	    my $url_new_both_full =
		build_view_file_url($topic, $current_file, $BOTH_FILES,
				    $current_new_file_linenumber, "R", $mode);
	    my $url_new_both = "javascript: myOpen('$url_new_both_full','CVS')";

	    print $query->Tr($query->td({-class=>'line', -colspan=>'2'},
					$query->a({href=>"$url_old"}, "Line " .
						  "$current_old_file_linenumber") .
					" | " .
					$query->a({href=>"$url_old_both"},
						  "Parallel")),
			     $query->td({-class=>'line', -colspan=>'2'},
					$query->a({href=>"$url_new"}, "Line " .
						  "$current_new_file_linenumber") .
					" | " .
					$query->a({href=>"$url_new_both"},
						  "Parallel"))),
					"\n";
	} else {
	    # No match in the repository - or a new file.  Just display
	    # the headings.
	    print $query->Tr($query->td({-class=>'line', -colspan=>'2'},
					"Line $current_old_file_linenumber"),
			     $query->td({-class=>'line', -colspan=>'2'},
					"Line $current_new_file_linenumber")),
			     "\n";
	}
    }
    else {
	if ($data =~ /^\-(.*)$/) {
	    # Line corresponds to something which has been removed.
	    add_old_change($1, $leftline, $offset);
	} elsif ($data =~ /^\+(.*)$/) {
	    # Line corresponds to something which has been removed.
	    add_new_change($1, $rightline, $offset);
	} elsif ($data =~ /^\\/) {
	    # A diff comment such as "No newline at end of file" - ignore it.
	} else {
	    # Strip the first space off the diff for proper alignment.
	    $data =~ s/^\s//;

	    # Render the previous diff changes visually.
	    render_changes($topic, $mode, $parallel);

	    # Render the current line for both cells.
	    my $celldata = render_coloured_cell($data);
	    my $left_prefix = $parallel ? "L" : "";
	    my $right_prefix = $parallel ? "R" : "";

	    # Determine the appropriate classes to render.
	    my $cell_class = ($mode == $COLOURED_MODE) ? "n" : "msn";

	    my $rendered_left_linenumber =
		render_linenumber($leftline, $offset, $left_prefix, $topic,
				  $mode, $parallel);
	    my $rendered_right_linenumber =
		($leftline == $rightline) ? $rendered_left_linenumber :
		render_linenumber($rightline, $offset, $right_prefix, $topic,
				  $mode, $parallel);

	    print $query->Tr($query->td($rendered_left_linenumber),
			     $query->td({-class=>$cell_class}, $celldata),
			     $query->td($rendered_right_linenumber),
			     $query->td({-class=>$cell_class}, $celldata),
			     "\n");
	}
    }
}

# Render a cell for the coloured diff.
sub render_coloured_cell($)
{
    my ($data) = @_;
    
    if (! defined $data || $data eq "") {
	return "&nbsp;";
    }

    # Replace spaces and tabs with the appropriate number of &nbsp;'s.
    $data = tabadjust($data, 1);
    $data =~ s/\s/&nbsp;/g;

    # Unconditionally add a &nbsp; at the start for better alignment.
    return "&nbsp;$data";
}

# Indicate a line of data which has been removed in the diff.
sub add_old_change($$$) {
    my ($data, $linenumber, $offset) = @_;
    push @diff_old_lines, $data;
    push @diff_old_lines_numbers, $linenumber;
    push @diff_old_lines_offsets, $offset;
}

# Indicate that a line of data has been added in the diff.
sub add_new_change($$$) {
    my ($data, $linenumber, $offset) = @_;
    push @diff_new_lines, $data;
    push @diff_new_lines_numbers, $linenumber;
    push @diff_new_lines_offsets, $offset;
}

# Render the current diff changes, if there is anything.
sub render_changes($$$) {
    my ($topic, $mode, $parallel) = @_;

    return if ($#diff_new_lines == -1 && $#diff_old_lines == -1);

    my ($arg1, $arg2, $arg3, $arg4);
    if ($#diff_new_lines != -1 && $#diff_old_lines != -1) {
	# Lines have been added and removed.
	if ($mode == $COLOURED_MODE) {
	    $arg1 = "c"; $arg2 = "cb"; $arg3 = "c"; $arg4 = "cb";
	} else {
	    $arg1 = "msc"; $arg2 = "mscb"; $arg3 = "msc"; $arg4 = "mscb";
	}
    } elsif ($#diff_new_lines != -1 && $#diff_old_lines == -1) {
	# New lines have been added.
	if ($mode == $COLOURED_MODE) {
	    $arg1 = "a"; $arg2 = "ab"; $arg3 = "a"; $arg4 = "ab";
	} else {
	    $arg1 = "msa"; $arg2 = "msab"; $arg3 = "msa"; $arg4 = "msab";
	}
    } else {
	# Lines have been removed.
	if ($mode == $COLOURED_MODE) {
	    $arg1 = "r"; $arg2 = "rb"; $arg3 = "r"; $arg4 = "rb";
	} else {
	    $arg1 = "msr"; $arg2 = "msrb"; $arg3 = "msr"; $arg4 = "msrb";
	}
    }
    render_inplace_changes($arg1, $arg2, $arg3, $arg4, $topic, $mode,
			   $parallel);

    # Now that the diff changeset has been rendered, remove the state data.
    @diff_new_lines = ();
    @diff_new_lines_numbers = ();
    @diff_new_lines_offsets = ();
    @diff_old_lines = ();
    @diff_old_lines_numbers = ();
    @diff_old_lines_offsets = ();
}

# Render the inplace changes in the current diff change set.
sub render_inplace_changes($$$$$$$)
{
    my ($old_col, $old_notpresent_col, $new_col, $new_notpresent_col,
	$topic, $mode, $parallel) = @_;

    my $old_data;
    my $new_data;
    my $old_data_line;
    my $new_data_line;
    my $old_data_offset;
    my $new_data_offset;
    while ($#diff_old_lines != -1 || $#diff_new_lines != -1) {

	# Retrieve the next lines which were removed (if any).
	if ($#diff_old_lines != -1) {
	    $old_data = shift @diff_old_lines;
	    $old_data_line = shift @diff_old_lines_numbers;
	    $old_data_offset = shift @diff_old_lines_offsets;
	} else {
	    undef($old_data);
	    undef($old_data_line);
	    undef($old_data_offset);
	}

	# Retrieve the next lines which were added (if any).
	if ($#diff_new_lines != -1) {
	    $new_data = shift @diff_new_lines;
	    $new_data_line = shift @diff_new_lines_numbers;
	    $new_data_offset = shift @diff_new_lines_offsets;
	} else {
	    undef($new_data);
	    undef($new_data_line);
	    undef($new_data_offset);
	}

	my $render_old_data = render_coloured_cell($old_data);
	my $render_new_data = render_coloured_cell($new_data);
	
	# Set the colours to use appropriately depending on what is defined.
	my $render_old_colour = $old_col;
	my $render_new_colour = $new_col;
	if (defined $old_data && ! defined $new_data) {
	    $render_new_colour = $new_notpresent_col;
	} elsif (! defined $old_data && defined $new_data) {
	    $render_old_colour = $old_notpresent_col;
	}

	my $old_prefix = $parallel ? "L" : "";
	my $new_prefix = $parallel ? "R" : "";
	print $query->Tr($query->td(render_linenumber($old_data_line,
						      $old_data_offset,
						      $old_prefix, $topic,
						      $mode, $parallel)),
			 $query->td({-class=>"$render_old_colour"},
				    $render_old_data),
			 $query->td(render_linenumber($new_data_line,
						      $new_data_offset,
						      $new_prefix, $topic,
						      $mode, $parallel)),
			 $query->td({-class=>"$render_new_colour"},
				    $render_new_data), "\n");
    }
}
	

# Render a linenumber as a hyperlink.  If the line already has a
# comment made against it, render it with $comment_line_colour.  The
# title of the link should be set to the comment digest, and the
# status line should be set if the mouse moves over the link.
# Clicking on the link will take the user to the add comment page.
sub render_linenumber($$$$$$) {
    my ($line, $offset, $prefix, $topic, $mode, $parallel) = @_;

    if (! defined $line) {
	return "&nbsp;";
    }

    # Determine what class to use when rendering the number.
    my ($comment_class, $no_comment_class);
    if ($parallel) {
	$comment_class = "com";
	$no_comment_class = "nocom";
    } else {
	$comment_class = "smscom";
	$no_comment_class = "smsnocom";
    }

    my $linedata;
    if ($offset != -1 && defined $comment_exists{$offset}) {
	if ($mode == $NORMAL_MODE) {
	    $linedata = "<FONT COLOR=\"$comment_line_colour\">$line</FONT>";
	} else {
	    $linedata = $query->span({-class=>$comment_class}, $line);
	}
    } else {
	if ($mode == $NORMAL_MODE) {
	    $linedata = $line;
	} else {
	    $linedata = $query->span({-class=>$no_comment_class}, $line);
	}
    }
    
    # Check if the linenumber is outside the review.
    if ($offset == -1) {
	return $linedata;
    }

    my $link_title = get_comment_digest($offset);
    my $js_title = $link_title;
    $js_title =~ s/\'/\\\'/mg;
    my $edit_url = build_edit_url($offset, $topic, "", "");
    $edit_url = "javascript:fetch('$edit_url')" if ($prefix ne "");
    if ($link_title ne "") {
	return $query->a(
			 {name=>"$prefix$line",
			  href=>$edit_url,
			  title=>$link_title,
			  onmouseover=>"window.status='$js_title'; " .
			      "return true;"}, "$linedata");
    } else {
	return $query->a({name=>"$prefix$line", href=>"$edit_url"},
			 "$linedata");
    }
}

# Handle the submission of a comment.
sub submit_comments ($$$$$$) {
    my ($line, $topic, $comments, $email, $cc, $mode) = @_;

    # Check that the fields have been filled appropriately.
    if ($comments eq "" || !defined $comments) {
	error_return("No comments were entered");
    }
    if ($email eq "" || !defined $email) {
	error_return("No email address was entered");
    }

    # get the localtime these comments were received.
    my $dateinfo = get_time_string(time);

    # Retrieve the comment lines and remove the \r from it.
    my @lines = split /\n/, $comments;
    my $line_length = $#lines+1;
    for (my $i = 0; $i <= $#lines; $i++) {
	$lines[$i] =~ s/\r//;
    }	

    # Send an email to the owner of the topic, and CC all people who have
    # submitted comments for this particular line number.
    read_document_file($topic, 1);
    read_comment_file($topic);
    my %contributors = ();
    $contributors{$email} = 1;
    my $cc_recipients = "";
    for (my $i = 0; $i <= $#comment_linenumber; $i++) {
	if ($comment_linenumber[$i] == $line &&
	    $comment_author[$i] ne $document_author &&
	    ! exists $contributors{$comment_author[$i]}) {
	    $contributors{$comment_author[$i]} = 1;
	    $cc_recipients .= "$comment_author[$i], ";
	}
    }

    # Remove the last space and comma character.
    if ($cc_recipients ne "") {
	substr($cc_recipients, -2) = "";
    }

    # Add the $cc recipients if any were specified.
    if (defined $cc)
    {
	if ($cc_recipients ne "")
	{
	    $cc_recipients .= make_canonical_email_list($cc);
	}
	else
	{
	    $cc_recipients = make_canonical_email_list($cc);
	}
    }

    # Send an email to the document author and all contributors with the
    # relevant information.  The person who wrote the comment is indicated
    # in the "From" field, and is BCCed the email so they retain a copy.
    my $topic_url = build_edit_url($line, $topic, "", $query->url());
    open(MAIL, "| $sendmail -t") || error_return("Unable to send email: $!");
    print MAIL "From: $email\n";
    print MAIL "To: $document_author\n";

    if (defined $cc_recipients && $cc_recipients ne "")
    {
	print MAIL "Cc: $cc_recipients\n";
    }
    print MAIL "Bcc: $email\n";
    print MAIL "Subject: [REVIEW] Topic \"$document_title\" comment added by $email\n\n";
    print MAIL "$email added a comment to Topic \"$document_title\".\n\n";
    print MAIL "URL: $topic_url\n\n";

    # Try to determine what file and line number this comment refers to.
    my $filename = "";
    my $file_linenumber = 0;
    my $accurate = 0;
    get_file_linenumber($topic, $line, \$filename, \$file_linenumber,
			\$accurate);
    if ($filename ne "") {
	if ($file_linenumber > 0) {
	    print MAIL "File: $filename" . ($accurate ? "" : " around") .
		" line $file_linenumber.\n\n";
	}
	else {
	    print MAIL "File: $filename\n\n";
	}
    }

    print MAIL "Context:\n";
    print MAIL "$email_hr\n\n";
    print MAIL get_context($line, $topic, $email_context, 0), "\n";
    print MAIL "$email_hr\n\n";
    
    # Now display comments relevant to this line, in reverse order.
    # First displayed the comment that has been received.
    print MAIL "$email $dateinfo\n\n";
    for (my $i = 0; $i <= $#lines; $i++) {
	print MAIL "$lines[$i]\n";
    }
    print MAIL "\n$email_hr\n\n";

    # Now display the comments that have already been submitted.
    for (my $i = $#comment_linenumber; $i >= 0; $i--) {
	if ($comment_linenumber[$i] == $line) {
	    my $data = $comment_data[$i];

	    print MAIL "$comment_author[$i] $comment_date[$i]\n\n$data\n";
	    print MAIL "$email_hr\n\n";
	}
    }
    print MAIL ".\n";

    # Check if there were any error messages from sendmail.
    if (! close MAIL) {
	generate_header($topic, $document_title, $email, "", "",
			$mode, $background_col);
	error_return("Failed to send email");
    }

    # The email was sent successfully, append the comment to the file.
    my $metadata = "$line_length $line $email";

    # Append the new comment to the file, and make sure exclusive access
    # is obtained.
    open (FILE, ">>$datadir/$topic/$comment_file");
    lock(\*FILE);
    print FILE "$metadata $dateinfo\n";
    for (my $i = 0; $i < $line_length; $i++) {
	print FILE "$lines[$i]\n";
    }
    unlock(\*FILE);
    close FILE;

    # Redirect the browser to view the topic back at the same line number where
    # they were adding comments to.
    my $redirect_url =
	build_view_url_extended($topic, $line, $mode, "", $email,
				$query->url());
    print $query->redirect(-URI=>"$redirect_url");
    return;
}

# Present a new form which will allow a user to create a new topic.
sub create_topic () {
    generate_header("", "", "", "", "", "", $background_col);
    print $query->h1("Create new topic"), $query->p;
    print $query->start_multipart_form();
    $query->param(-name=>'action', -value=>'submit_topic');
    print $query->hidden(-name=>'action', -default=>'submit_topic');
    print "Topic title: ", $query->br;
    print $query->textfield(-name=>'topic_title',
			    -size=>70,
			    -maxlength=>70);
    print $query->p, "Topic description: ", $query->br;
    print $query->textarea(-name=>'topic_description',
			   -rows=>5,
			   -columns=>70,
			   -wrap=>'hard');
    # Don't wrap the topic text, in case people are cutting and pasting code
    # rather than using the file upload.
    print $query->p, "Topic text: ", $query->br;
    print $query->textarea(-name=>'topic_text',
			   -rows=>15,
			   -columns=>70);

    print $query->p, $query->start_table();
    print $query->Tr($query->td("Topic text upload: "),
		     $query->td($query->filefield(-name=>'topic_file',
						  -size=>40,
						  -maxlength=>200)));
    print $query->Tr($query->td("Bug IDs: "),
		     $query->td($query->textfield(-name=>'bug_ids',
						  -size=>30,
						  -maxlength=>50)));
    my $default_email = get_email();
    print $query->Tr($query->td("Your email address: "),
		     $query->td($query->textfield(-name=>'email',
						  -size=>50,
						  -default=>"$default_email",
						  -override=>1,
						  -maxlength=>80)));
    my $default_reviewers = get_reviewers();
    print $query->Tr($query->td("Reviewers: "),
		     $query->td($query->textfield(-name=>'reviewers',
						  -size=>50,
						  -default=>"$default_reviewers",
						  -override=>1,
						  -maxlength=>150)));
    my $default_cc = get_cc();
    print $query->Tr($query->td("Cc: "),
		     $query->td($query->textfield(-name=>'cc',
						  -size=>50,
						  -default=>"$default_cc",
						  -override=>1,
						  -maxlength=>150)));
    print $query->end_table();
    print $query->p, $query->submit(-value=>'submit');
    print $query->end_form();
}

# Given a list of email addresses separated by commas and spaces, return
# a canonical form, where they are separated by a comma and a space.
sub make_canonical_email_list($) {
    my ($emails) = @_;

    if (defined $emails && $emails ne "") {
	return join ', ', split /[\s\n\t,;]+/, $emails;
    } else {
	return $emails;
    }
}

# Given a list of bug ids separated by commas and spaces, return
# a canonical form, where they are separated by a comma and a space.
sub make_canonical_bug_list ($) {
    my ($bugs) = @_;

    if (defined $bugs && $bugs ne "") {
	return join ' ', split /[\s\n\t,;]+/, $bugs;
    } else {
	return "";
    }
}

# Handle the submission of a new topic.
sub submit_topic ($$$$$$$$) {
    my ($topic_title, $email, $topic_text, $topic_description,
	$reviewers, $cc, $fh, $bug_ids) = @_;

    # Check that the fields have been filled appropriately.
    if (! defined $topic_title || $topic_title eq "") {
	error_return("No topic title was entered");
    }
    if (! defined $topic_description || $topic_description eq "") {
	error_return("No topic description was entered");
    }
    if (! defined $email || $email eq "") {
	error_return("No email address was entered");
    }	
    if ((! defined $topic_text || $topic_text eq "") && (! defined $fh)) {
	error_return("No topic text or filename was entered");
    }
    if (defined $topic_text && defined $fh && $topic_text ne "") {
	error_return("Both topic text and uploaded file was entered");
    }
    if ( ! defined $reviewers || $reviewers eq "") {
	error_return("No reviewers were entered");
    }

    # Canonicalise the bug ids.
    $bug_ids = make_canonical_bug_list($bug_ids);

    # Create a directory where to copy the document, and to create the
    # comment file.
    srand;
    my $dirname = "";
    do {
	$dirname = int rand(10000000);
    } while (-e $dirname);
    mkdir "$datadir/$dirname", 0755;

    # Open the document file, putting the name of the owner in the first line
    # followed by the document text.
    if (! open (DOCUMENT, ">$datadir/$dirname/$document_file")) {
	error_return("Couldn't create document file in $dirname: $!");
    }

    my @description = split /\n/, $topic_description;
    my $description_length = $#description + 1;

    # Change the Cc and Reviewers to be in a canoncial comma separated
    # form.
    $cc = make_canonical_email_list($cc);
    $reviewers = make_canonical_email_list($reviewers);

    # Write out the topic metadata.
    print DOCUMENT "Author: $email\n";
    print DOCUMENT "Title: $topic_title\n";
    print DOCUMENT "Bug: $bug_ids\n";
    print DOCUMENT "Reviewers: $reviewers\n";
    print DOCUMENT "Cc: $cc\n" if (defined $cc && $cc ne "");
    print DOCUMENT "Description: $description_length\n";

    # Write out the topic description.
    for (my $i = 0; $i <= $#description; $i++) {
	$description[$i] =~ s/\r//;
	print DOCUMENT "$description[$i]\n";
    }
    print DOCUMENT "Text\n";

    if (defined $fh) {
	# Enter the data from the uploaded file.
	while (<$fh>) {
	    print DOCUMENT "$_";
	}
    } else {
	# Enter the data from the topic text.
	my @lines = split /\n/, $topic_text;
	for (my $i = 0; $i <= $#lines; $i++) {
	    $lines[$i] =~ s/\r//o;
	    print DOCUMENT "$lines[$i]\n";
	}
    }
    close DOCUMENT;

    # Create an empty comment file.
    if (! open (COMMENT, ">$datadir/$dirname/$comment_file")) {
	error_return("Couldn't create comment file in $dirname: $!");
    }
    close COMMENT;

    generate_header($dirname, $topic_title, $email, $reviewers, $cc,
		    "", $background_col);

    # Process the document file.  If it is in CVS unidiff format, then
    # extract all the information possible to allow for intelligent
    # displaying later.
    process_document($dirname);

    # Send the author, reviewers and the cc an email with the same information.
    my $topic_url = build_view_url_extended($dirname, -1,
					    $default_topic_create_mode, "", "",
					    $query->url());
    open (MAIL, "| $sendmail -t") || error_return("Unable to send email: $!");
    print MAIL "From: $email\n";
    print MAIL "To: $reviewers\n";
    print MAIL "Cc: $cc\n";
    print MAIL "Bcc: $email\n";
    print MAIL "Subject: [REVIEW] Topic \"$topic_title\" created\n";
    print MAIL "Topic \"$topic_title\" created\n";
    print MAIL "Author: $email\n";
    print MAIL "Bug IDs: $bug_ids\n" if ($bug_ids ne "");
    print MAIL "Reviewers: $reviewers\n";
    print MAIL "URL: $topic_url\n\n";
    print MAIL "Description:\n";
    print MAIL "$email_hr\n\n";

    # Display the topic description.
    for (my $i = 0; $i <= $#description; $i++) {
	print MAIL "$description[$i]\n";
    }

    if (! close(MAIL)) {
	# Remove the files which were just created and report the error
	# message.
	unlink("$datadir/$dirname/$document_file");
	unlink("$datadir/$dirname/$comment_file");
	rmdir("$datadir/$dirname");
	error_return("Failed to send email");
    }

    # Indicate to the user that the document has been created.
    print $query->h1("Topic created");
    print "Topic title: \"$topic_title\"", $query->br;
    print "Author: $email", $query->br;
    print "Topic URL: ", $query->a({href=>"$topic_url"}, $topic_url);
    print $query->p, "Email has been sent to: $email, $reviewers";
    print ", $cc" if (defined $cc && $cc ne "");
}

# Go through the document, and if it is a CVS unidiff file, extract each diff
# into their own file, and create a filetable file to record which files
# there are, what their CVS revisions are, what are the line offsets and what
# diff file are they stored in.
sub process_document($) {
    my ($dirname) = @_;

    if (! open (DOCUMENT, "$datadir/$dirname/$document_file")) {
	error_return("Could not open document file in $dirname: $!");
    }

    # Read the meta-data part of the document.
    while (<DOCUMENT>) {
	last if (/^Text$/o);
    }

    my $offset = 1;
    my $line = <DOCUMENT>;
    my @filenames = ();
    my @revisions = ();
    my @offsets = ();
    my $filename = "";
    my $revision = "";
    for (my $diff_number = 0;
	 read_diff_header(\*DOCUMENT, \$offset, \$filename, \$revision, $line);
	 $diff_number++) {
	# The filehandle is now positioned in the interesting part of the
	# file.
	push @filenames, $filename;
	push @revisions, $revision;
	push @offsets, $offset;

	if (! open (DIFF, ">$datadir/$dirname/diff.$diff_number")) {
	    error_return("Could not create diff.$diff_number: $!");
	}

	while (<DOCUMENT>) {
	    $offset++;
	    last if (/^Index/o || /^diff/o); # The start of the next diff header.
	    print DIFF $_;
	}
	close DIFF;
    }
    close DOCUMENT;

    # Write out the file table.
    if (! open(FILETABLE, ">$datadir/$dirname/$filetable_file")) {
	error_return("Could not create filetable in $dirname: $!");
    }
    for (my $i = 0; $i <= $#filenames; $i++) {
	print FILETABLE "|$filenames[$i]| $revisions[$i] $offsets[$i]\n";
    }
    close FILETABLE;
}

# Read from $fh, and return true if we have read a diff header, with all of
# the appropriate values set to the reference variables passed in.
sub read_diff_header($$$$$) {
    my ($fh, $offset, $filename, $revision, $line) = @_;

    # read any ? lines, denoting unknown files to CVS.
    while ($line =~ /^\?/o) {
	$line = <$fh>;
	$$offset++;
    }
    return 0 unless defined $line;

    # For CVS diffs, the Index line is next.
    if ($line =~ /^Index:/o) {
	$line = <$fh>;
	return 0 unless defined $line;
	$$offset++;
    }
    
    # Then we expect the separator line, for CVS diffs.
    if ($line =~ /^===================================================================$/) {
	$line = <$fh>;
	return 0 unless defined $line;
	$$offset++;
    }

    # Now we expect the RCS line, whose filename should include the CVS
    # repository, and if not, it is probably a new file.  if there is no such
    # line, we could still be dealing with an ordinary patch file.
    my $cvs_diff = 0;
    if ($line =~ /^RCS file: $cvsrep\/(.*),v$/) {
	$$filename = $1;
	$line = <$fh>;
	return 0 unless defined $line;
	$$offset++;
	$cvs_diff = 1;
    } elsif ($line =~ /^RCS file: (.*)$/o) {
	$$filename = $1;
	$line = <$fh>;
	return 0 unless defined $line;
	$$offset++;
	$cvs_diff = 1;
    }

    # Now we expect the retrieving revision line, unless it is a new or
    # removed file.
    if ($line =~ /^retrieving revision (.*)$/o) {
	$$revision = $1;
	$line = <$fh>;
	return 0 unless defined $line;
	$$offset++;
    }
    
    # Now read in the diff line, followed by the legend lines.  If this is
    # not present, then we know we aren't dealing with a diff file of any
    # kind.
    return 0 unless $line =~ /^diff/o;
    $line = <$fh>;
    return 0 unless defined $line;
    $$offset++;

    if ($line =~ /^\-\-\- \/dev\/null/o) {
	# File has been added.
	$$revision = $ADDED_REVISION;
    } elsif ($cvs_diff == 0 &&
	     $line =~ /^\-\-\- (.*)\t(Mon|Tue|Wed|Thu|Fri|Sat|Sun).*$/o) {
	$$filename = $1;
	$$revision = $PATCH_REVISION;
    } elsif (! $line =~ /^\-\-\-/o) {
	return 0;
    }

    $line = <$fh>;
    return 0 unless defined $line;
    $$offset++;
    if ($line =~ /^\+\+\+ \/dev\/null/o) {
	# File has been removed.
	$$revision = $REMOVED_REVISION;
    } elsif (! $line =~ /^\+\+\+/o) {
	return 0;
    }

    # Now up to the line chunks, so the diff header has been successfully read.
    return 1;
}

# Print out a line of data with the specified line number suitably aligned,
# and with tabs replaced by spaces for proper alignment.
sub render_monospaced_line ($$$$$$$$$) {
    my ($topic, $linenumber, $data, $offset, $max_digit_width,
	$max_line_length, $class, $parallel, $mode) = @_;

    my $prefix = "";
    my $digit_width = length($linenumber);
    for (my $i = 0; $i < ($max_digit_width - $digit_width); $i++) {
	$prefix .= " ";
    }

    # Determine what class to use when rendering the number.
    my ($comment_class, $no_comment_class);
    if ($parallel == 0) {
	$comment_class = "mscom";
	$no_comment_class = "msnocom";
    } else {
	if ($mode == $COLOURED_MODE) {
	    $comment_class = "com";
	    $no_comment_class = "nocom";
	} else {
	    $comment_class = "smscom";
	    $no_comment_class = "smsnocom";
	}
    }

    # Render the line data.  If the user clicks on a topic line, the
    # main window is moved to the edit page.  I'm not sure if this is
    # the best thing from a useability perspective, but we'll see for
    # now.
    my $line_cell = "";
    if ($offset != -1) {
	# A line corresponding to the review.
	my $edit_url = build_edit_url($offset, $topic, "", "");
	if (defined $comment_exists{$offset}) {
	    my $link_title = get_comment_digest($offset);
	    my $js_title = $link_title;
	    $js_title =~ s/\'/\\\'/mgo;
	    $line_cell = "$prefix" .
		$query->a({name=>"$linenumber",
			   href=>"javascript:fetch('$edit_url')",
			   title=>$js_title,
			   onmouseover=> "window.status='$js_title'; " .
			       "return true;" },
			  $query->span({-class=>$comment_class},
				       "$linenumber"));
	}
	else {
	    $line_cell = "$prefix" .
		$query->a({name=>"$linenumber",
			   href=>"javascript:fetch('$edit_url')"},
			  $query->span({-class=>$no_comment_class},
				       "$linenumber"));
	}
    }
    else {
	# A line outside of the review.  Just render the line number, as
	# the "name" of the linenumber should not be used.
	$line_cell = "$prefix$linenumber";
    }

    $data = tabadjust($data, 0);
    my $newdata = CGI::escapeHTML($data);

    if ($class ne "") {
	# Add the appropriate number of spaces to justify the data to a length
	# of $max_line_length, and render it within a SPAN to get the correct
	# background colour.
	my $padding = $max_line_length - length($data);
	for (my $i = 0; $i < ($padding); $i++) {
	    $newdata .= " ";
	}
	return "$line_cell " .
	    $query->span({-class=>"$class"}, $newdata) . "\n";
    }
    else {
	return "$line_cell $newdata\n";
    }
}

# Record a plus line.
sub add_plus_monospace_line ($$) {
    my ($linedata, $offset) = @_;
    push @view_file_plus, $linedata;
    push @view_file_plus_offset, $offset;
}

# Record a minus line.
sub add_minus_monospace_line ($$) {
    my ($linedata, $offset) = @_;
    push @view_file_minus, $linedata;
    push @view_file_minus_offset, $offset;
}

# Flush the current diff chunk, and update the line count.  Note if the
# original file is being rendered, the minus lines are used, otherwise the
# plus lines.
sub flush_monospaced_lines ($$$$$$$) {
    my ($topic, $new, $linenumber_ref, $max_digit_width,
	$max_line_length, $parallel, $mode) = @_;

    my $class = "";
    if ($#view_file_plus != -1 && $#view_file_minus != -1) {
	# This is a change chunk.
	$class = "msc";
    }
    elsif ($#view_file_plus != -1) {
	# This is an add chunk.
	$class = "msa";
    }
    elsif ($#view_file_minus != -1) {
	# This is a remove chunk.
	$class = "msr";
    }

    if ($new) {
	for (my $i = 0; $i <= $#view_file_plus; $i++) {
	    print render_monospaced_line($topic, $$linenumber_ref,
					 $view_file_plus[$i],
					 $view_file_plus_offset[$i],
					 $max_digit_width,
					 $max_line_length, $class,
					 $parallel, $mode);
	    $$linenumber_ref++;
	}
    }
    else {
	for (my $i = 0; $i <= $#view_file_minus; $i++) {
	    print render_monospaced_line($topic, $$linenumber_ref,
					 $view_file_minus[$i],
					 $view_file_minus_offset[$i],
					 $max_digit_width,
					 $max_line_length, $class,
					 $parallel, $mode);
	    $$linenumber_ref++;
	}
    }
    $#view_file_minus = -1;
    $#view_file_minus_offset = -1;
    $#view_file_plus = -1;
    $#view_file_plus_offset = -1;
}	

# Show the contents of a file, and indicate whether it is the file before
# modification (pre-patch), after or to show both.
sub view_file ($$$$) {
    my ($topic, $filename, $new, $mode) = @_;

    # Read the filetable.
    if (!read_filetable_file($topic)) {
	error_return("Unable to read filetable for topic $topic: $!");
    }

    # Locate the file of interest, and retrieve the relevant information.
    my $offset = "";
    my $diff_number = "";
    my $revision = "";
    my $index;
    for ($index = 0; $index <= $#filetable_filename; $index++) {
	if ($filetable_filename[$index] eq $filename) {
	    $offset = $filetable_offset[$index];
	    $revision = $filetable_revision[$index];
	    last;
	}
    }
    if ($index > $#filetable_filename) {
	error_return("Unable to locate filetable information");
    }

    # Load the appropriate CVS file into memory.
    read_cvs_file($filename, $revision);

    # Read the comment file to know which offsets have comments made against
    # them.
    read_comment_file($topic);

    # Open the patch file corresponding to this file.
    if (! open(PATCH, "$datadir/$topic/diff.$index")) {
	error_return("Could not open patch file for $filename");
    }

    # This could be done more efficiently, but for now, read through the
    # PATCH file, and determine the longest line length for the resulting
    # data hat is to be viewed.  Note it is not 100% accurate, but it will
    # do for now, to reduce the resulting page size.
    my $max_line_length = $cvs_filedata_max_line_length;
    while (<PATCH>) {
	if (/^\s(.*)$/o || /^\+(.*)$/o || /^\-(.*)$/o) {
	    my $line_length = length($1);
	    if ($line_length > $max_line_length) {
		$max_line_length = $line_length;
	    }
	}
    }

    # Close and re-open the PATCH file for processing.
    close PATCH;
    if (! open(PATCH, "$datadir/$topic/diff.$index")) {
	error_return("Could not open patch file for $filename");
    }
    
    # Output the new file, with the appropriate patch applied.
    my $title = $new == $NEW_FILE ? "New $filename" : "$filename v$revision";
    generate_header($topic, $title, "", "", "", "", $diff_background_col);

    my $parallel;
    if ($new == $BOTH_FILES) {
	print_coloured_table();
	$parallel = 1;
    }
    else {
	print "<PRE class=\"ms\">\n";
	$parallel = 0;
    }

    my $max_digit_width = length($#cvs_filedata);
    my $patch_line = <PATCH>;
    my $linenumber = 1;
    my $old_linenumber = 1;
    my $new_linenumber = 1;
    my $chunk_end = 1;
    my $next_chunk_end = 1;
    while (1) {
	# Read the next line of patch information.
	my $patch_line_start;
	if ($patch_line =~ /^\@\@ \-(\d+),(\d+) \+\d+,\d+ \@\@.*$/o) {
	    $patch_line_start = $1;
	    $next_chunk_end = $1 + $2;
	}
	else {
	    # Last chunk in the patch file, display to the end of the file.
	    $patch_line_start = $#cvs_filedata;
	}
	
	# Output those lines leading up to $patch_line_start.  These lines
	# are not part of the review, so they can't be acted upon.
	for (my $i = $chunk_end; $i < $patch_line_start; $i++, $linenumber++) {
	    if ($new == $BOTH_FILES) {
		display_coloured_data($old_linenumber, $new_linenumber, -1,
				      $parallel, $max_digit_width,
				      " $cvs_filedata[$i]", "", "", "", 0, 0,
				      0, 0, $topic, $mode, 1, "");
		$old_linenumber++;
		$new_linenumber++;
	    }
	    else {
		print render_monospaced_line($topic, $linenumber,
					     $cvs_filedata[$i], -1,
					     $max_digit_width,
					     $max_line_length, "",
					     $parallel, $mode);
	    }
	}
	
	# Read the information from the patch, and "apply" it to the
	# output.
	while (<PATCH>) {
	    $offset++;
	    my $data = tabadjust($_, 0);

	    # Handle the processing of the side-by-side view separately.
	    if ($new == $BOTH_FILES &&
		($data =~ /^\s/o || $data =~ /^\-/o || $data =~ /^\+/o)) {
		display_coloured_data($old_linenumber, $new_linenumber,
				      $offset, $parallel, $max_digit_width, $_,
				      "", "", "", 0, 0, 0, 0, $topic,
				      $mode, 1, "");
		$old_linenumber++ if $data =~ /^\s/o || $data =~ /^\-/o;
		$new_linenumber++ if $data =~ /^\s/o || $data =~ /^\+/o;
		next;
	    }

	    if (/^\s(.*)$/o) {
		# An unchanged line, output it and anything pending.
		flush_monospaced_lines($topic, $new, \$linenumber,
				       $max_digit_width, $max_line_length,
				       $parallel, $mode);
		print render_monospaced_line($topic, $linenumber, $1, $offset,
					     $max_digit_width,
					     $max_line_length, "",
					     $parallel, $mode);
		$linenumber++;
	    } elsif (/^\-(.*)$/o) {
		# A removed line.
		add_minus_monospace_line($1, $offset);
	    } elsif (/^\+(.*)$/o) {
		# An added line.
		add_plus_monospace_line($1, $offset);
	    } elsif (/^\\/o) {
		# A line with a diff comment, such as:
		# \ No newline at end of file.
		# The easiest way to deal with these lines is to just ignore
		# them.
	    } elsif (/^@@/o) {
		# Start of next diff block, exit from loop and flush anything
		# pending.
		if ($new != $BOTH_FILES) {
		    flush_monospaced_lines($topic, $new, \$linenumber,
					   $max_digit_width, $max_line_length,
					   $parallel, $mode);
		}
		$patch_line = $_;
		last;
	    } else {
		error_return("Unable to handle patch line: $_");
	    }
	}

	$chunk_end = $next_chunk_end;

	if (!defined $_) {
	    if ($new != $BOTH_FILES) {
		# Reached the end of the patch file.  Flush anything pending.
		flush_monospaced_lines($topic, $new, \$linenumber,
				       $max_digit_width, $max_line_length,
				       $parallel, $mode);
	    }
	    last;
	}
    }

    # Display the last part of the file.
    for (my $i = $chunk_end; $i <= $#cvs_filedata; $i++, $linenumber++) {
	if ($new == $BOTH_FILES) {
	    display_coloured_data($old_linenumber, $new_linenumber, -1,
				  $parallel, $max_digit_width,
				  " $cvs_filedata[$i]", "", "", "", 0, 0, 0,
				  0, $topic, $mode, 1, "");
	    $old_linenumber++;
	    $new_linenumber++;
	}
	else {
	    print render_monospaced_line($topic, $linenumber,
					 $cvs_filedata[$i], -1,
					 $max_digit_width, $max_line_length,
					 "", $parallel, $mode);
	}
    }

    if ($new == $BOTH_FILES) {
	print $query->end_table();
    }
    else {
	print "</PRE>\n";
    }
    print $query->end_html();
    close PATCH;
}

# Given a topic and topic line number, try to determine the line
# number of the new file it corresponds to.  For topic lines which
# were made against '+' lines or unchanged lins, this will give an
# accurate result.  For other situations, the number returned will be
# approximate.  The results are returned in $filename_ref,
# $linenumber_ref and $accurate_ref references.
sub get_file_linenumber ($$$$$)
{
    my ($topic, $topic_linenumber,
	$filename_ref, $linenumber_ref, $accurate_ref) = @_;
    
    # Check if this topic has a filetable.
    if (!read_filetable_file($topic)) {
	$$filename_ref = "";
	return;
    }
    
    # Find the appropriate file the $topic_linenumber refers to.
    my $diff_limit = -1;
    my $index;
    for ($index = 0; $index <= $#filetable_filename; $index++) {
	last if ($filetable_offset[$index] > $topic_linenumber);
    }

    # Check if the comment was made against a diff header.
    if ($index <= $#filetable_offset) {
	my $diff_header_size;
	if ($filetable_revision[$index] eq $ADDED_REVISION ||
	    $filetable_revision[$index] eq $REMOVED_REVISION) {
	    # Added or removed file.
	    $diff_header_size = 6;
	}
	elsif ($filetable_revision[$index] eq $PATCH_REVISION) {
	    # Patch file
	    $diff_header_size = 3;
	}
	else {
	    # Normal CVS diff header.
	    $diff_header_size = 7;
	}

	if ( ($topic_linenumber >=
	      $filetable_offset[$index] - $diff_header_size) &&
	     ($topic_linenumber <= $filetable_offset[$index]) ) {
	    $$filename_ref = $filetable_filename[$index];
	    $$linenumber_ref = -1;
	    $$accurate_ref = 0;
	    return;
	}
    }
    $index--;

    # Couldn't find a matching linenumber.
    if ($index < 0 || $index > $#filetable_filename) {
	$$filename_ref = "";
	return;
    }

    # Open the diff file that is contained within this range.
    if (!open(PATCH, "$datadir/$topic/diff.$index")) {
	$$filename_ref = "";
	return;
    }

    # Go through the patch file until we reach the topic linenumber of
    # interest.
    my $accurate_line = 0;
    my $newfile_linenumber = 0;
    my $current_topic_linenumber;
    for ($current_topic_linenumber = $filetable_offset[$index];
	 defined($_=<PATCH>) && $current_topic_linenumber <= $topic_linenumber;
	 $current_topic_linenumber++) {
	if (/^\@\@ \-\d+,\d+ \+(\d+),\d+ \@\@.*$/o) {
	    # Matching diff header, record what the current linenumber is now
	    # in the new file.
	    $newfile_linenumber = $1 - 1;
	    $accurate_line = 0;
	}
	elsif (/^\s.*$/o) {
	    # A line with no change.
	    $newfile_linenumber++;
	    $accurate_line = 1;
	}
	elsif (/^\+.*$/o) {
	    # A line corresponding to the new file.
	    $newfile_linenumber++;
	    $accurate_line = 1;
	}
	elsif (/^\-.*$/o) {
	    # A line corresponding to the old file.
	    $accurate_line = 0;
	}
    }

    if ($current_topic_linenumber >= $topic_linenumber) {
	# The topic linenumber was found.
	$$filename_ref = $filetable_filename[$index];
	$$linenumber_ref = $newfile_linenumber;
	$$accurate_ref = $accurate_line;
    }
    else {
	# The topic linenumber was not found.
	$$filename_ref = "";
    }
    close PATCH;
    return;
}

# Implement a gzipped file handle via the Compress:Zlib compression
# library.  This code was stolen from CVSweb.

sub MAGIC1() { 0x1f }
sub MAGIC2() { 0x8b }
sub OSCODE() { 3    }

sub TIEHANDLE {
	my ($class, $out) = @_;
	my $level = Compress::Zlib::Z_BEST_COMPRESSION();
	my $wbits = -Compress::Zlib::MAX_WBITS();
	my ($d) = Compress::Zlib::deflateInit(-Level => $level,
					      -WindowBits => $wbits)
	    or return undef;
	my ($o) = {
		handle => $out,
		dh => $d,
		crc => 0,
		len => 0,
	};
	my ($header) = pack("c10", MAGIC1, MAGIC2,
			    Compress::Zlib::Z_DEFLATED(),
			    0,0,0,0,0,0, OSCODE);
	print {$o->{handle}} $header;
	return bless($o, $class);
}

sub PRINT {
	my ($o) = shift;
	my ($buf) = join(defined $, ? $, : "",@_);
	my ($len) = length($buf);
	my ($compressed, $status) = $o->{dh}->deflate($buf);
	print {$o->{handle}} $compressed if defined($compressed);
	$o->{crc} = Compress::Zlib::crc32($buf, $o->{crc});
	$o->{len} += $len;
	return $len;
}

sub CLOSE {
	my ($o) = @_;
	return if !defined( $o->{dh});
	my ($buf) = $o->{dh}->flush();
	$buf .= pack("V V", $o->{crc}, $o->{len});
	print {$o->{handle}} $buf;
	undef $o->{dh};
}

sub DESTROY {
	my ($o) = @_;
	CLOSE($o);
}
