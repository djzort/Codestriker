###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Collection of routines for creating HTTP responses, including headers and
# error indications.

package Codestriker::Http::Response;

use strict;
use Codestriker::Http::Cookie;
use Codestriker::Http::UrlBuilder;
use HTML::Entities ();

# Constructor for this class.  Indicate that the response header hasn't been
# generated yet.
sub new($$) {
    my ($type, $query) = @_;
    
    my $self = {};
    $self->{header_generated} = 0;
    $self->{query} = $query;
    $self->{format} = $query->param('format');
    $self->{action} = $query->param('action');
    return bless $self, $type;
}

# Return the query object associated with the response.
sub get_query($) {
    my ($self) = @_;

    return $self->{query};
}

# Generate the initial HTTP response header, with the initial HTML header.
# Most of the input parameters are used for storage into the user's cookie.
sub generate_header {
    
    my ($self, %params) = @_;

    my $topic = undef;
    my $topic_title = "";
    my $email = "";
    my $reviewers = "";
    my $cc = "";
    my $mode = "";
    my $tabwidth = "";
    my $repository = "";
    my $projectid = "";
    my $load_anchor = "";
    my $topicsort = "";
    my $fview = -1;

    my $reload = $params{reload};
    my $cache = $params{cache};

    $load_anchor = $params{load_anchor};
    $load_anchor = "" if ! defined $load_anchor;

    # If the header has already been generated, do nothing.
    return if ($self->{header_generated});
    $self->{header_generated} = 1;
    my $query = $self->{query};

    # Set the topic and title parameters.
    $topic = $params{topic};
    $topic_title = $params{topic_title};

    # Set the fview parameter if defined.
    $fview = $params{fview} if defined $params{fview};

    # Set the cookie in the HTTP header for the $email, $cc, $reviewers and
    # $tabwidth parameters.
    my %cookie = ();

    if (! defined $params{email} || $params{email} eq "") {
	$email = Codestriker::Http::Cookie->get_property($query, 'email');
    }
    else {
        $email = $params{email};
    }

    if (! defined $params{reviewers} || $params{reviewers} eq "") {
	$reviewers = Codestriker::Http::Cookie->get_property($query,
							     'reviewers');
    }
    else {
        $reviewers = $params{reviewers};
    }

    if (! defined $params{cc} || $params{cc} eq "") {
	$cc = Codestriker::Http::Cookie->get_property($query, 'cc');
    }
    else {
        $cc = $params{cc};
    }

    if (! defined $params{tabwidth} || $params{tabwidth} eq "") {
	$tabwidth = Codestriker::Http::Cookie->get_property($query,
							    'tabwidth');
    }
    else {
        $tabwidth = $params{tabwidth};
    }

    if (! defined $params{mode} || $params{mode} eq "") {
	$mode = Codestriker::Http::Cookie->get_property($query, 'mode');
    }
    else {
        $mode = $params{mode};
    }

    if (! defined $params{repository} || $params{repository} eq "") {
	$repository = Codestriker::Http::Cookie->get_property($query,
							     'repository');
    }
    else {
        $repository = $params{repository};
    }

    if (! defined $params{projectid} || $params{projectid} eq "") {
	$projectid = Codestriker::Http::Cookie->get_property($query,
							     'projectid');
    }
    else {
        $projectid = $params{projectid};
    }

    if (! defined $params{topicsort} || $params{topicsort} eq "") {
	$topicsort = Codestriker::Http::Cookie->get_property($query,
							     'topicsort');
    }
    else {
        $topicsort = $params{topicsort};
    }

    $cookie{'email'} = $email if $email ne "";
    $cookie{'reviewers'} = $reviewers if $reviewers ne "";
    $cookie{'cc'} = $cc if $cc ne "";
    $cookie{'tabwidth'} = $tabwidth if $tabwidth ne "";
    $cookie{'mode'} = $mode if $mode ne "";
    $cookie{'repository'} = $repository if $repository ne "";
    $cookie{'projectid'} = $projectid if $projectid ne "";
    $cookie{'topicsort'} = $topicsort if $topicsort ne "";

    my $cookie_obj = Codestriker::Http::Cookie->make($query, \%cookie);

    # This logic is taken from cvsweb.  There is _reason_ behind this logic...
    # Basically mozilla supports gzip regardless even though some versions
    # don't state this.  IE claims it does, but doesn't support it.  Using
    # the gzip binary technique doesn't work apparently under mod_perl.
    
    # Determine if the client browser is capable of handled compressed HTML.
    eval {
	require Compress::Zlib;
    };
    my $output_compressed = 0;
    my $has_zlib = !$@;
    my $browser = $ENV{'HTTP_USER_AGENT'};
    my $can_compress = ($Codestriker::use_compression &&
			((defined($ENV{'HTTP_ACCEPT_ENCODING'})
			  && $ENV{'HTTP_ACCEPT_ENCODING'} =~ m|gzip|)
			 || $browser =~ m%^Mozilla/3%)
			&& ($browser !~ m/MSIE/)
			&& !(defined($ENV{'MOD_PERL'}) && !$has_zlib));

    # Output the appropriate header if compression is allowed to the client.
    if ($can_compress &&
	($has_zlib || ($Codestriker::gzip ne "" &&
		       open(GZIP, "| $Codestriker::gzip -1 -c")))) {
	if ($cache) {
	    print $query->header(-cookie=>$cookie_obj,
				 -content_encoding=>'x-gzip',
				 -charset=>"UTF-8",
				 -vary=>'Accept-Encoding');
	} else {
	    print $query->header(-cookie=>$cookie_obj,
				 -expires=>'+1d',
				 -charset=>"UTF-8",
				 -cache_control=>'no-store',
				 -pragma=>'no-cache',
				 -content_encoding=>'x-gzip',
				 -vary=>'Accept-Encoding');
	}

	# Flush header output, and switch STDOUT to GZIP.
	$| = 1; $| = 0;
	if ($has_zlib) {
	    tie *GZIP, __PACKAGE__, \*STDOUT;
	}
	select(GZIP);
	$output_compressed = 1;
    } else {
        # Make sure the STDOUT encoding is set to UTF8.  Not needed
        # when the data is being sent as compressed bytes.
	binmode STDOUT, ':utf8';
	if ($cache) {
	    print $query->header(-cookie=>$cookie_obj,
					 -charset=>"UTF-8");
	} else {
	    print $query->header(-cookie=>$cookie_obj,
				 -expires=>'+1d',
				 -charset=>"UTF-8",
				 -cache_control=>'no-store',
				 -pragma=>'no-cache');
	}
    }

    my $title = "Codestriker";
    if (defined $topic_title && $topic_title ne "") {
	$title .= ": \"$topic_title\"";
    }
    $title = HTML::Entities::encode($title);

    # Generate the URL to the codestriker CSS file.
    my $codestriker_css;
    if (defined $Codestriker::codestriker_css &&
	$Codestriker::codestriker_css ne "") {
		if ($Codestriker::codestriker_css =~ /[\/\\]/o) {
			# Assume CSS file is specified with absolute path.
			$codestriker_css = $Codestriker::codestriker_css;
		} else {
			# Assume CSS file is in case html directory, just under
			# a different name.
			$codestriker_css = $query->url();
			$codestriker_css =~ s#/[^/]+?/codestriker\.pl#/codestrikerhtml/$Codestriker::codestriker_css#;
		}
    } else {
    	# Use the default CSS file.
			$codestriker_css = $query->url();
			if (defined $Codestriker::cgi_style && $Codestriker::cgi_style) {
	            $codestriker_css =~ s#/[^/]+?/codestriker\.pl#/codestrikerhtml/codestriker.css#;
			} else {
				$codestriker_css = $query->url() . "/html/codestriker.css";
			}
    }

    
    my $codestrikerhtml_path = $codestriker_css;
    $codestrikerhtml_path =~ s/\/[\w\-]*.css/\//;
    my $overlib_js = $codestrikerhtml_path . "overlib.js";
    my $overlib_centerpopup_js = $codestrikerhtml_path . "overlib_centerpopup.js";
    my $overlib_draggable_js = $codestrikerhtml_path . "overlib_draggable.js";
    my $xbdhtml_js = $codestrikerhtml_path . "xbdhtml.js";
    my $codestriker_js = $codestrikerhtml_path . "codestriker.js";
    

    # Print the basic HTML header header, with the inclusion of the scripts.
    # Make sure a DOCTYPE is used which will put IE 6 and above into
    # "standards-compliant mode": http://msdn.microsoft.com/en-us/library/ms535242(VS.85).aspx.
    print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">';
    print "\n";
    print '<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US">';
    print "\n";
    print "<head><title>$title</title>\n";
    print "<link rel=\"stylesheet\" type=\"text/css\" href=\"$codestriker_css\" />\n";
    print "<script src=\"$overlib_js\" type=\"text/javascript\"></script>\n";
    print "<script src=\"$overlib_centerpopup_js\" type=\"text/javascript\"></script>\n";
    print "<script src=\"$overlib_draggable_js\" type=\"text/javascript\"></script>\n";
    print "<script src=\"$xbdhtml_js\" type=\"text/javascript\"></script>\n";
    print "<script src=\"$codestriker_js\" type=\"text/javascript\"></script>\n";
    print "<script type=\"text/javascript\">\n";
    print "    var cs_load_anchor = '$load_anchor';\n";
    print "    var cs_reload = $reload;\n";
    print "    var cs_topicid = $topic->{topicid};\n" if defined $topic;
    print "    var cs_projectid = $topic->{project_id};\n" if defined $topic;
    print "    var cs_email = '$email';\n" if defined $email;
    print "    var cs_css = '$codestriker_css';\n";
    print "    var cs_xbdhtml_js = '$xbdhtml_js';\n";

    # Now output all of the comment metric information.
    print "    var cs_metric_data = new Array();\n";
    my $i = 0;
    foreach my $metric_config (@{ $Codestriker::comment_state_metrics }) {
	print "    cs_metric_data[$i] = new Object();\n";
	print "    cs_metric_data[$i].name = '" .
	    $metric_config->{name} . "';\n";
	print "    cs_metric_data[$i].values = new Array();\n";
	my $j = 0;
	foreach my $value (@{ $metric_config->{values} }) {
	    print "    cs_metric_data[$i].values[$j] = '$value';\n";
	    $j++;
	}
	if (defined $metric_config->{default_value}) {
	    print "    cs_metric_data[$i].default_value = '" .
		$metric_config->{default_value} . "';\n";
	}
	$i++;
    }
    
    # Output the URL to post to for adding comments.
    if (defined $topic) {
        my $url_builder = Codestriker::Http::UrlBuilder->new($self->{query});
        print "    var cs_add_comment_url = '" .
              $url_builder->add_comment_url(topicid => $topic->{topicid}, projectid => $topic->{project_id}) . "';\n";
    }

    # Check that the external javascript files were loaded, and if not
    # output an error message.  This is usually due to a
    # misconfiguration.
    print "    if ('function' != typeof window.add_comment_html) {\n";
    print "        alert('Oh oh... can\\'t find codestriker.js, please check your web-server config.');\n";
    print "    }\n";

    print "</script>\n";

    # Output the comment declarations if the $comments array is defined.
    my $comments = $params{comments};
    if (defined $comments) {
	print generate_comment_declarations($topic, $comments, $query,
					    $fview, $tabwidth);
    }

    # Write an HTML comment indicating if response was sent compressed or not.
    $self->{output_compressed} = $output_compressed;
    print "\n<!-- Source was" . (!$output_compressed ? " not" : "") .
	" sent compressed. -->\n";
}

# Return the javascript code necessary to support viewing/modification of
# comments.
sub generate_comment_declarations
{
    my ($topic, $comments, $query, $fview, $tabwidth) = @_;

    # The output html to return.
    my $html = "";

    # Build a hash from filenumber|fileline|new -> comment array, to record
    # what comments are associated with what locations.  Also record the
    # order of comment_locations found.
    my %comment_hash = ();
    my @comment_locations = ();
    for (my $i = 0; $i <= $#$comments; $i++) {
	my $comment = $$comments[$i];
	my $key = $comment->{filenumber} . "|" . $comment->{fileline} . "|" .
	    $comment->{filenew};
	if (! exists $comment_hash{$key}) {
	    push @comment_locations, $key;
	}
        push @{ $comment_hash{$key} }, $comment;
    }

    # Precompute the overlib HTML for each comment location.
    $html .= "\n<script language=\"JavaScript\" type=\"text/javascript\">\n";

    # Add the reviewers for the review here.
    $html .= "    var topic_reviewers = '" . $topic->{reviewers} . "';\n";

    # Now record all the comments made so far in the topic.
    $html .= "    var comment_text = new Array();\n";
    $html .= "    var comment_hash = new Array();\n";
    $html .= "    var comment_metrics = new Array();\n";
    my $index;
    for ($index = 0; $index <= $#comment_locations; $index++) {

	# Contains the overlib HTML text.
	my $overlib_html = "";

	# Determine what the previous and next comment locations are.
	my $previous = undef;
	my $next = undef;
	if ($index > 0) {
	    $previous = $comment_locations[$index-1];
	}
	if ($index < $#comment_locations) {
	    $next = $comment_locations[$index+1];
	}

	# Compute the previous link if required.
	my $current_url = $query->self_url();
	if (defined $previous && $previous =~ /^(\-?\d+)|\-?\d+|\d+$/o) {
	    my $previous_fview = $1;
	    my $previous_index = $index - 1;
	    my $previous_url = $current_url;
	    $previous_url =~ s/fview=\d+/fview=$previous_fview/o if $fview != -1;
	    $previous_url .= '#' . $previous;
	    $overlib_html .= "<a href=\"javascript:window.location=\\'$previous_url\\'; ";
	    if ($fview == -1 || $fview == $previous_fview) {
		$overlib_html .= "overlib(comment_text[$previous_index], STICKY, DRAGGABLE, ALTCUT, FIXX, getEltPageLeft(getElt(\\'$previous\\')), FIXY, getEltPageTop(getElt(\\'$previous\\'))); ";
}
	    $overlib_html .= "void(0);\">Previous</a>";
	}

	# Compute the next link if required.
	if (defined $next && $next =~ /^(\-?\d+)|\-?\d+|\d+$/o) {
	    my $next_fview = $1;
	    $overlib_html .= " | " if defined $previous;
	    my $next_index = $index + 1;
	    my $next_url = $current_url;
	    $next_url =~ s/fview=\d+/fview=$next_fview/o if $fview != -1;
	    $next_url .= '#' . $next;
	    $overlib_html .= "<a href=\"javascript:window.location=\\'$next_url\\'; ";
	    if ($fview == -1 || $fview == $next_fview) {
		$overlib_html .= "overlib(comment_text[$next_index], STICKY, DRAGGABLE, ALTCUT, FIXX, getEltPageLeft(getElt(\\'$next\\')), FIXY, getEltPageTop(getElt(\\'$next\\'))); ";
	    }
	    $overlib_html .= "void(0);\">Next</a>";
	}
	if (defined $previous || defined $next) {
	    $overlib_html .= " | ";
	}

	# Add an add comment link.
	my $key = $comment_locations[$index];
	$key =~ /^(\-?\d+)\|(\-?\d+)\|(\d+)$/o;
	if (!Codestriker::topic_readonly($topic->{topic_state})) {
	    $overlib_html .= "<a href=\"javascript:add_comment_tooltip($1,$2,$3)" .
		"; void(0);\">Add Comment<\\/a> | ";
	}

	# Add a close link.
	$overlib_html .= "<a href=\"javascript:hideElt(getElt(\\'overDiv\\')); void(0);\">Close<\\/a><p>";

	# Create the actual comment text.
	my @comments = @{ $comment_hash{$key} };

	for (my $i = 0; $i <= $#comments; $i++) {
	    my $comment = $comments[$i];

	    # Need to format the data appropriately for HTML display.
	    my $data = HTML::Entities::encode($comment->{data});
	    $data =~ s/\\/\\\\/mgo;
	    $data =~ s/\'/\\\'/mgo;
	    $data =~ s/\n/<br>/mgo;
	    $data =~ s/ \s+/'&nbsp;' x (length($&)-1)/emgo;
	    $data = Codestriker::tabadjust($tabwidth, $data, 1);

	    # Show each comment with the author and date in bold.
	    $overlib_html .= "<b>Comment from $comment->{author} ";
	    $overlib_html .= "on $comment->{date}<\\/b><br>";
	    $overlib_html .= "$data";

	    # Add a newline at the end if required.
	    if ($i < $#comments &&
		substr($overlib_html, length($overlib_html)-4, 4) ne '<br>') {
		$overlib_html .= '<br>';
	    }
	}

	$html .= "    comment_text[$index] = '$overlib_html';\n";
        $html .= "    comment_hash['" . $comment_locations[$index] .
	    "'] = $index;\n";

	# Store the current metric values for this comment.
	$html .= "    comment_metrics[$index] = new Array();\n";
	my $comment_metrics = $comments[0]->{metrics};
	foreach my $metric_config (@{ $Codestriker::comment_state_metrics }) {
	    my $value = $comment_metrics->{$metric_config->{name}};
	    $value = "" unless defined $value;
	    $html .= "    comment_metrics[${index}]['" .
		$metric_config->{name} . "'] = '" . $value . "';\n";
	}

    }
    $html .= "</script>\n";

    # Now declare the CSS positional elements for each comment location.
    $html .= "<style type=\"text/css\">\n";
    for (my $i = 0; $i <= $#$comments; $i++) {
	$html .= '#c' . $i . ' { position: absolute; }' . "\n";
    }
    $html .= "</style>\n";

    # Return the generated HTML.
    return $html;
}


# Close the response, which only requires work if we are dealing with
# compressed streams.
sub generate_footer($) {
    my ($self) = @_;

    if ($self->{output_compressed}) {
	select(STDOUT);
	close(GZIP);
	untie *GZIP;
    }
}

# Generate an error page response if bad input was passed in.
sub error($$) {
    my ($self, $error_message) = @_;

    my $query = $self->{query};

    # Check if the expected format is XML.
    if (defined $self->{format} && $self->{format} eq "xml") {
	print $query->header(-content_type=>'text/xml');
	print "<?xml version=\"1.0\" encoding=\"UTF-8\" " .
	            "standalone=\"yes\"?>\n";
	print "<response><method>" . $self->{action} . "</method>" .
	    "<result>" . HTML::Entities::encode($error_message) .
	    "</result></response>\n";
    }
    else {
	if (! $self->{header_generated}) {
	    print $query->header,
	    $query->start_html(-title=>'Codestriker error',
			       -bgcolor=>'white');
	}

	print $query->p, "<FONT COLOR='red'>$error_message</FONT>", $query->p;
	print $query->end_html();

	$self->generate_footer();
    }

    exit;
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
	my ($header) = pack("C10", MAGIC1, MAGIC2,
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

1;
