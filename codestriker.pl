#!/usr/bin/perl -wT

###############################################################################
# Codestriker: Copyright (c) 2001 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
# Version 1.0
#
# Codestriker is a perl CGI script which is used for performing code reviews
# in a collaborative fashion as opposed to using unstructured emails.
#
# Authors create code review topics, where the nominated reviewers will be
# automaticaly notified by email.  Reviewers then submit comments against
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

use CGI;
use CGI::Carp 'fatalsToBrowser';

use FileHandle;
use IPC::Open2;

#use diagnostics -verbose;

# Location of where to store the code review data.  Make sure the
# permissions are set appropriately.  If running apache, make sure the
# following directory is writable to the user running httpd (usually
# "nobody" or "apache").  Each topic is stored in its own sub-directory,
# whose name is just a random bunch of digits.
$datadir="/var/www/codestriker";

# Location of sendmail.
$sendmail = "/usr/lib/sendmail";

# Set the PATH to something sane.
$ENV{'PATH'} = "/bin:/usr/bin";

# Don't allow post large than 500K.
$CGI::POST_MAX=1024 * 500;

# Need to call this: slashcode.  have nice graphic with:
# if (a = b) {
#    write_data();
# }
# with a big cross in red - all in the background with Codestriker in the
# foreground.

# TODO
# * Be good to trim leading and trailing newlines.
# * Get things working with "use strict".
# * Put simple small jpg logo on the top of each page.
# * If increase/decrease context, don't lose data already typed.
# * Show number of comments for a specific line number as well.

# Day strings
@days = ("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
	 "Saturday");

# Month strings
@months = ("January", "Februrary", "March", "April", "May", "June", "July",
	   "August", "September", "October", "November", "December");

# Default context width for line-based reviews.
$context = 2;

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

# The document data is stored as an array of strings, indexed by line number.
@document = ();

# The document title.
$document_title = "";

# The document description.
@document_description = ();

# The document reviewers.
$document_reviewers = "";

# The Cc list to be informed of the new topic.
$document_cc = "";

# The document author.
$document_author = "";

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

# Record if the HTML header has been generated yet or not.
$header_generated_record = 0;

# Subroutine prototypes.
sub edit_topic($$$$);
sub view_topic($$);
sub submit_comments($$$$);
sub create_topic();
sub submit_topic($$$$$$$);
sub error_return($);
sub display_context($$$);
sub read_document_file($);
sub read_comment_file($);
sub lock($);
sub unlock($);
sub get_email();
sub get_reviewers();
sub get_cc();
sub build_edit_url($$$);
sub build_view_url($$$);
sub build_create_topic_url();
sub generate_header($$$$$);
sub header_generated();
sub get_comment_digest($);
sub get_context($$$$);
sub untaint_topic($);
sub untaint_email($);
sub untaint_emails($);
sub make_canoncial_email_list($);
sub main();

# Call main to kick things off.
main;

sub main() {
    # Retrieve he CGI parameters.
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

    # Untaint the required input.
    $topic = untaint_topic($topic);
    $email = untaint_email($email);
    $reviewers = untaint_emails($reviewers);
    $cc = untaint_emails($cc);

    # Perform the action specified in the "action" parameter.
    # If the action is not specified, assume a new topic is to be created.
    if (! defined $action || $action eq "") {
	create_topic();
    }
    elsif ($action eq "edit") {
	edit_topic($line, $topic, $context, $email);
    }	
    elsif ($action eq "view") {
	view_topic($topic, $email);
    }
    elsif ($action eq "submit_comment") {
	submit_comments($line, $topic, $comments, $email);
    }
    elsif ($action eq "create") {
	create_topic();
    }
    elsif ($action eq "submit_topic") {
	submit_topic($topic_title, $email, $topic_text, $topic_description,
		     $reviewers, $cc, $topic_text_fh);
    }
    else {
	create_topic();
    }

    print $query->end_html();
    return;
}

# Untaint $topic, which should be just a bunch of random digits.
sub untaint_topic($) {
    my ($topic) = @_;

    if (defined $topic && $topic ne "") {
	if ($topic =~ /^(\d+)$/) {
	    return $1;
	} else {
	    error_return("Invalid topic \"$topic\" - you naughty boy.");
	}
    } else {
	return $topic;
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
	if ($emails =~ /^([-_@\w,\.\s]+)$/) {
	    return $1;
	} else {
	    error_return("Invalid email list \"$emails\" - you naughty boy.");
	}
    } else {
	return $emails;
    }
}
    

# Return true if the header has been generated already, false otherwise.
sub header_generated() {
    return ($header_generated_record != 0);
}

# Generate the HTTP header and start of the body.
sub generate_header($$$$$) {
    my ($topic, $topic_title, $email, $reviewers, $cc) = @_;

    # Check if the header has already been generated (in the case of an error).
    return if (header_generated());
    $header_generated_record = 1;

    # Set the cookie in the HTTP header for the $email, $cc, and $reviewers
    # parameters.
    my %cookie_value; 
    if (defined $query->cookie("$cookie_name")) {
	%cookie_value = $query->cookie("$cookie_name");
    }

    $cookie_value{'email'} = $email if (defined $email && $email ne "");
    $cookie_value{'reviewers'} = $reviewers
	if (defined $reviewers && $reviewers ne "");
    $cookie_value{'cc'} = $cc if (defined $cc && $cc ne "");

    my $cookie_path = $query->url(-absolute=>1);
    my $cookie = $query->cookie(-name=>"$cookie_name",
				-expires=>'+10y',
				-path=>"$cookie_path",
				-value=>\%cookie_value);
    print $query->header(-cookie=>$cookie);

    my $title = "Codestriker";
    if (defined $topic_title && $topic_title ne "") {
	$title .= ": \"$topic_title\"";
    }
    print $query->start_html(-dtd=>'-//W3C//DTD HTML 3.2 Final//EN',
			     -title=>"$title",
			     -bgcolor=>'white',
			     -link=>'blue',
			     -vlink=>'purple');
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

# Report the error message, and close of the HTML stream.
sub error_return ($) {
    my ($error_message) = @_;
    if (! header_generated()) {
	print $query->header, $query->start_html(-title=>'Codestriker error',
						 -bgcolor=>'white');
    }
    print $query->p, "<FONT COLOR='red'>$error_message</FONT>", $query->p;
    print "Press the \"back\" button, fix the problem and try again.";
    print $query->end_html();
    exit 0;
}

# Read the topic's document file.
sub read_document_file($) {
    my ($topic) = @_;

    if (! open(DOCUMENT, "$datadir/$topic/$document_file")) {
	error_return("Unable to open document file for topic \"$topic\": $!");
    }
    
    # Parse the document metadata.
    while (<DOCUMENT>) {
	my $data = $_;
	if ($data =~ /^Author: (.+)$/) {
	    $document_author = $1;
	} elsif ($data =~ /^Title: (.+)$/) {
	    $document_title = $1;
	} elsif ($data =~ /^Reviewers: (.+)$/) {
	    $document_reviewers = $1;
	} elsif ($data =~ /^Cc: (.+)$/) {
	    $document_cc = $1;
	} elsif ($data =~ /^Description: (\d+)$/) {
	    my $description_length = $1;

	    # Read the document description.
	    @document_description = ();
	    for (my $i = 0; $i < $description_length; $i++) {
		my $data = <DOCUMENT>;
		chop $data;
		# Change tabs with spaces to preserve alignment during display.
		$data =~ s/\t/        /g;
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
	$data =~ s/\t/        /g;
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
	/^(\d+) (\d+) ([-_\@\w\.]+) (.*)$/;
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

# Create the URL for viewing a topic.
sub build_view_url ($$$) {
    my ($topic, $line, $email) = @_;
    return "?topic=$topic&action=view" .
	((defined $email && $email ne "") ? "&email=$email" : "") .
	    ($line != -1 ? "#${line}" : "");
}	    

# Create the URL for creating a topic.
sub build_create_topic_url () {
    return "?action=create";
}	    

# Create the URL for editing a topic.
sub build_edit_url ($$$) {
    my ($line, $topic, $context) = @_;
    return "?line=$line&topic=$topic&action=edit&context=$context";
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
		$data = CGI::escapeHTML($data);
		$digest .= "$data ------- ";
	    }
	}
	# Chop off the last 9 characters.
	substr($digest, -9) = "";
    }
    
    return $digest;
}

# Add a comment to a specific line.
sub edit_topic ($$$$) {
    my ($line, $topic, $context, $email) = @_;

    # Read the document and comment file for this topic.
    read_document_file($topic);
    read_comment_file($topic);

    # Display the header of this page.
    generate_header($topic, $document_title, $email, "", "");
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

    my $view_url = $query->url() . build_view_url($topic, $line, $email);
    print $query->p, $query->a({href=>"$view_url"},"View topic");
    print $query->p, $query->hr, $query->p;

    # Display the context in question.  Allow the user to increase it
    # or decrease it appropriately.
    my $inc_context = ($context <= 0) ? 1 : $context*2;
    my $dec_context = ($context <= 0) ? 0 : int($context/2);
    my $inc_context_url = $query->url() .
	build_edit_url($line, $topic, $inc_context);
    my $dec_context_url = $query->url() .
	build_edit_url($line, $topic, $dec_context);
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
	    print $query->br;
	    print $query->pre(CGI::escapeHTML($comment_data[$i])), $query->p;
	}
    }
    
    # Create a form which will allow the user to enter in some comments.
    print $query->hr, $query->p("Enter comments:"), $query->p;
    print $query->start_form();
    $query->param(-name=>'action', -value=>'submit_comment');
    print $query->hidden(-name=>'action', -default=>'submit_comment');
    print $query->hidden(-name=>'line', -default=>"$line");
    print $query->hidden(-name=>'topic', -default=>"$topic");
    print $query->textarea(-name=>'comments',
			   -rows=>15,
			   -columns=>75,
			   -wrap=>'hard');

    print $query->p, "Your email address: ";

    my $default_email = get_email();
    print $query->textfield(-name=>'email',
			    -size=>50,
			    -default=>"$default_email",
			    -override=>1,
			    -maxlength=>80);
    print $query->p;
    print $query->submit(-value=>'submit');
    print $query->end_form();
}

# View the specified code review topic.
sub view_topic ($$) {
    my ($topic, $email) = @_;

    read_document_file($topic);
    read_comment_file($topic);

    # Display header information
    generate_header($topic, $document_title, $email, "", "");
    my $escaped_title = CGI::escapeHTML($document_title);
    print $query->h2("$escaped_title");

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

    print "<PRE>\n";
    for (my $i = 0; $i <= $#document_description; $i++) {
	my $data = CGI::escapeHTML($document_description[$i]);
	print "$data\n";
    }
    print "</PRE>\n";

    my $number_comments = $#comment_linenumber + 1;
    my $url = $query->url() . build_view_url($topic, -1, $email);
    if ($number_comments == 1) {
	print "Only one ", $query->a({href=>"${url}#comments"},
				     "comment");
	print " submitted", $query->p;
    } elsif ($number_comments > 1) {
	print "$number_comments ", $query->a({href=>"${url}#comments"},
					     "comments");
	print " submitted", $query->p;
    }

    print $query->p, $query->hr, $query->p;

    # Number of characters the line number should take.
    my $max_digit_width = length($#document+1);

    # Display the data that is being reviewed.
    print "<PRE>\n";
    for (my $i = 0; $i <= $#document; $i++) {
	my $digit_width = length($i);
	my $data = CGI::escapeHTML($document[$i]);
	my $url = $query->url() . build_edit_url($i, $topic, $context);

	# Add the necessary number of spaces for alignment
	for (my $j = 0; $j < ($max_digit_width - $digit_width); $j++) {
	    print " ";
	}
	
	my $linenumber = defined $comment_exists{$i} ?
	    "<FONT COLOR=\"$comment_line_colour\">$i</FONT>" : "$i";

	my $link_title = get_comment_digest($i);
	my $js_title = $link_title;
	$js_title =~ s/\'/\\\'/mg;
	if ($link_title ne "") {
	    print $query->a(
			    {name=>"$i",
			     href=>"$url",
			     title=>"$link_title",
			     onmouseover=>"window.status='$js_title'; return true;"
			 },
			    "$linenumber");
	} else {
	    print $query->a({name=>"$i", href=>"$url"},"$linenumber");
	}
	print " ", $data, $query->br;
    }
    print "</PRE>\n", $query->p;
    
    # Now display all comments in reverse order.  Put an anchor in for the
    # first comment.
    for (my $i = $#comment_linenumber; $i >= 0; $i--) {
	my $edit_url = $query->url() . build_edit_url($comment_linenumber[$i],
						      $topic, $context);
	if ($i == $#comment_linenumber) {
	    print $query->a({name=>"comments"},$query->hr);
	} else {
	    print $query->hr;
	}
	print $query->a({href=>"$edit_url"},
			"line $comment_linenumber[$i]"), ": ";
	print "$comment_author[$i] $comment_date[$i]", $query->br;
	print $query->pre(CGI::escapeHTML($comment_data[$i])), $query->p;
    }
}

# Handle the submission of a comment.
sub submit_comments ($$$$) {
    my ($line, $topic, $comments, $email) = @_;

    # Check that the fields have been filled appropriately.
    if ($comments eq "" || !defined $comments) {
	error_return("No comments were entered");
    }
    if ($email eq "" || !defined $email) {
	error_return("No email address was entered");
    }

    # get the localtime these comments were received.
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime(time);
    $year += 1900;
    my $dateinfo = "$days[$wday], $mday $months[$mon], $year";

    # Retrieve the comment lines and remove the \r from it.
    my @lines = split /\n/, $comments;
    my $line_length = $#lines+1;
    for (my $i = 0; $i <= $#lines; $i++) {
	$lines[$i] =~ s/\r//;
    }	

    # Send an email to the owner of the topic, and CC all people who have
    # submitted comments for this particular line number.
    read_document_file($topic);
    read_comment_file($topic);
    my %contributors = ();
    $contributors{$email} = 1;
    my $cc_recipients = "$email, ";
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

    # Send an email to the document author and all contributors with the
    # relevant information.
    my $topic_url = $query->url() . build_edit_url($line, $topic, $context);
    my ($rdr, $MAIL) = (FileHandle->new, FileHandle->new);
    open2($rdr, $MAIL, "$sendmail -t") ||
	error_return("Unable to send email: $!");
    print $MAIL "To: $document_author\n";
    print $MAIL "Cc: $cc_recipients\n";
    print $MAIL "Subject: [REVIEW] Topic \"$document_title\" comment added by $email\n\n";
    print $MAIL "$email added a comment to Topic \"$document_title\".\n";
    print $MAIL "URL: $topic_url\n\n";
    print $MAIL "Context:\n";
    print $MAIL "$email_hr\n\n";
    print $MAIL get_context($line, $topic, $email_context, 0), "\n";
    print $MAIL "$email_hr\n\n";
    
    # Now display comments relevant to this line, in reverse order.
    # First displayed the comment that has been received.
    printf $MAIL ("$email %02d:%02d:%02d $dateinfo\n\n", $hour, $min, $sec);
    for (my $i = 0; $i <= $#lines; $i++) {
	print $MAIL "$lines[$i]\n";
    }
    print $MAIL "\n$email_hr\n\n";

    # Now display the comments that have already been submitted.
    for (my $i = $#comment_linenumber; $i >= 0; $i--) {
	if ($comment_linenumber[$i] == $line) {
	    my $data = $comment_data[$i];

	    print $MAIL "$comment_author[$i] $comment_date[$i]\n\n$data\n";
	    print $MAIL "$email_hr\n\n";
	}
    }
    print $MAIL ".\n";

    # Check if there were any error messages from sendmail.
    my $mail_errors = "";
    while (<$rdr>) {
	$mail_errors .= $_;
    }

    if ($mail_errors ne "") {
	generate_header($topic, $document_title, $email, "", "");
	error_return("Failed to send email: \"$mail_errors\"");
    }

    # The email was sent successfully, append the comment to the file.
    my $metadata = "$line_length $line $email";

    # Append the new comment to the file, and make sure exclusive access
    # is obtained.
    open (FILE, ">>$datadir/$topic/$comment_file");
    lock(\*FILE);
    printf FILE ("$metadata %02d:%02d:%02d $dateinfo\n", $hour, $min, $sec);
    for (my $i = 0; $i < $line_length; $i++) {
	print FILE "$lines[$i]\n";
    }
    unlock(\*FILE);
    close FILE;

    # Redirect the browser to view the topic back at the same line number where
    # they were adding comments to.
    my $redirect_url = $query->url() . build_view_url($topic, $line, $email);
    print $query->redirect(-URI=>"$redirect_url");
    return;
}

# Present a new form which will allow a user to create a new topic.
sub create_topic () {
    generate_header("", "", "", "", "");
    print $query->h1("Create new topic"), $query->p;
    print $query->start_multipart_form();
    $query->param(-name=>'action', -value=>'submit_topic');
    print $query->hidden(-name=>'action', -default=>'submit_topic');
    print "Topic title: ", $query->br;
    print $query->textfield(-name=>'topic_title',
			    -size=>90,
			    -maxlength=>90);
    print $query->p, "Topic description: ", $query->br;
    print $query->textarea(-name=>'topic_description',
			   -rows=>5,
			   -columns=>90,
			   -wrap=>'hard');

    print $query->p, "Topic text: ", $query->br;
    print $query->textarea(-name=>'topic_text',
			   -rows=>15,
			   -columns=>90,
			   -wrap=>'hard');
    print $query->p, "Topic text upload: ";
    print $query->filefield(-name=>'topic_file',
			    -size=>50,
			    -maxlength=>200);

    print $query->p, $query->start_table();
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
						  -maxlength=>100)));
    my $default_cc = get_cc();
    print $query->Tr($query->td("Cc: "),
		     $query->td($query->textfield(-name=>'cc',
						  -size=>50,
						  -default=>"$default_cc",
						  -override=>1,
						  -maxlength=>80)));
    print $query->end_table();
    print $query->p, $query->submit(-value=>'submit');
    print $query->end_form();
}

# Given a list of email addresses separated by commas and spaces, return
# a canonical form, where they are separated by a comma and a space.
sub make_canoncial_email_list($) {
    my ($emails) = @_;

    if (defined $emails && $emails ne "") {
	my $result = "";
	while ($emails =~ /^[\s\,]*([-_\@\w\.]+)[\s\,]*(.*)$/) {
	    $result .= "$1, ";
	    $emails = $2;
	}
	substr($result, -2) = "" if ($result ne "");
	return $result;
    } else {
	return $emails;
    }
}

# Handle the submission of a new topic.
sub submit_topic ($$$$$$$) {
    my ($topic_title, $email, $topic_text, $topic_description,
	$reviewers, $cc, $fh) = @_;

    # Check that the fields have been filled appropriately.
    if ( ! defined $topic_title || $topic_title eq "") {
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
    $cc = make_canoncial_email_list($cc);
    $reviewers = make_canoncial_email_list($reviewers);

    # Write out the topic metadata.
    print DOCUMENT "Author: $email\n";
    print DOCUMENT "Title: $topic_title\n";
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
	    $lines[$i] =~ s/\r//;
	    print DOCUMENT "$lines[$i]\n";
	}
    }
    close DOCUMENT;

    # Create an empty comment file.
    if (! open (COMMENT, ">$datadir/$dirname/$comment_file")) {
	error_return("Couldn't create comment file in $dirname: $!");
    }
    close COMMENT;

    generate_header($dirname, $topic_title, $email, $reviewers, $cc);

    # Send the author, reviewers and the cc an email with the same information.
    my $topic_url = $query->url() . build_view_url($dirname, -1, "");
    open (MAIL, "| $sendmail -t") || error_return("Unable to send email: $!");
    print MAIL "To: $email, $reviewers\n";
    print MAIL "Cc: $cc\n";
    print MAIL "Subject: [REVIEW] Topic \"$topic_title\" created\n";
    print MAIL "Topic \"$topic_title\" created\n";
    print MAIL "Author: $email\n";
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



