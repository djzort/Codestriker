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

# Constructor for this class.  Indicate that the response header hasn't been
# generated yet.
sub new($$) {
    my ($type, $query) = @_;
    
    my $self = {};
    $self->{header_generated} = 0;
    $self->{query} = $query;
    return bless $self, $type;
}

# Return the query object associated with the response.
sub get_query($) {
    my ($self) = @_;

    return $self->{query};
}

# Generate the initial HTTP response header, with the initial HTML header.
# Most of the input parameters are used for storage into the user's cookie.
sub generate_header($$$$$$$$$$$) {
    my ($self, $topic, $topic_title, $email, $reviewers, $cc, $mode,
	$tabwidth, $repository, $load_anchor, $reload, $cache) = @_;

    # If the header has already been generated, do nothing.
    return if ($self->{header_generated});
    $self->{header_generated} = 1;
    my $query = $self->{query};

    # Set the cookie in the HTTP header for the $email, $cc, $reviewers and
    # $tabwidth parameters.
    my %cookie = ();

    if (!defined $email || $email eq "") {
	$email = Codestriker::Http::Cookie->get_property($query, 'email');
    }
    if (!defined $reviewers || $reviewers eq "") {
	$reviewers = Codestriker::Http::Cookie->get_property($query,
							     'reviewers');
    }
    if (!defined $cc || $cc eq "") {
	$cc = Codestriker::Http::Cookie->get_property($query, 'cc');
    }
    if (!defined $tabwidth || $tabwidth eq "") {
	$tabwidth = Codestriker::Http::Cookie->get_property($query,
							    'tabwidth');
    }
    if (!defined $mode || $mode eq "") {
	$mode = Codestriker::Http::Cookie->get_property($query, 'mode');
    }
    if (!defined $repository || $repository eq "") {
	$repository = Codestriker::Http::Cookie->get_property($query,
							     'repository');
    }

    $cookie{'email'} = $email if $email ne "";
    $cookie{'reviewers'} = $reviewers if $reviewers ne "";
    $cookie{'cc'} = $cc if $cc ne "";
    $cookie{'tabwidth'} = $tabwidth if $tabwidth ne "";
    $cookie{'mode'} = $mode if $mode ne "";
    $cookie{'repository'} = $repository if $repository ne "";

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
				 -vary=>'Accept-Encoding');
	} else {
	    print $query->header(-cookie=>$cookie_obj,
				 -expires=>'+1d',
				 -cache_control=>'no-store',
				 -pragma=>'no-cache'
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
	if ($cache) {
	    print $query->header(-cookie=>$cookie_obj);
	} else {
	    print $query->header(-cookie=>$cookie_obj,
				 -expires=>'+1d',
				 -cache_control=>'no-store',
				 -pragma=>'no-cache');
	}
    }

    my $title = "Codestriker";
    if (defined $topic_title && $topic_title ne "") {
	$title .= ": \"$topic_title\"";
    }

    # Generate the URL to the codestriker CSS file.
    my $codestriker_css = $query->url();
    $codestriker_css =~ s/codestriker\/codestriker\.pl/codestrikerhtml\/codestriker\.css/;

    # Write the simple open window javascript method for displaying popups.
    # Note gotoAnchor can't simply be:
    #
    # opener.location.hash = "#" + anchor;
    #
    # As the old netscapes don't handle it properly.
    my $jscript=<<END;
    var windowHandle = '';

    function myOpen(url,name) {
	windowHandle = window.open(url,name,
				   'toolbar=no,width=800,height=600,status=yes,scrollbars=yes,resizable=yes,menubar=no');
	// Indicate who initiated this operation.
        windowHandle.opener = window;

	windowHandle.focus();
    }

    function gotoAnchor(anchor, reload) {
	if (anchor == "" || opener == null) return;

	var index = opener.location.href.lastIndexOf("#");
	if (index != -1) {
	    opener.location.href =
		opener.location.href.substr(0, index) + "#" + anchor;
	}
	else {
	    opener.location.href += "#" + anchor;
	}
		
	if (reload) opener.location.reload(reload);
	opener.focus();
    }
END

    print $query->start_html(-dtd=>'-//W3C//DTD HTML 3.2 Final//EN',
			     -charset=>'ISO-8859-1',
			     -title=>"$title",
			     -bgcolor=>"#eeeeee",
			     -style=>{src=>"$codestriker_css"},
			     -base=>$query->url(),
			     -link=>'blue',
			     -vlink=>'purple',
			     -script=>$jscript,
			     -onLoad=>"gotoAnchor('$load_anchor', $reload)");

    # Write a comment indicating if this was compressed or not.
    print "\n<!-- Source was" . (!$output_compressed ? " not" : "") .
	" sent compressed. -->\n";
}

# Generate the footer of the HTML output.
sub generate_footer($) {
    my ($self) = @_;

    my $query = $self->{query};

    # Fix for bug relating to IE 5 + caching of documents, see:
    # http://support.microsoft.com/default.aspx?scid=kb;EN-US;q222064
#    print "</BODY><HEAD>\n" .
#	'<META HTTP-EQUIV="PRAGMA" CONTENT="NO-CACHE">' .
#	"</HEAD></HTML>\n";
}

# Generate an error page response if bad input was passed in.
sub error($$) {
    my ($self, $error_message) = @_;

    my $query = $self->{query};
    if (! $self->{generated_header}) {
	print $query->header, $query->start_html(-title=>'Codestriker error',
						 -bgcolor=>'white');
    }

    print $query->p, "<FONT COLOR='red'>$error_message</FONT>", $query->p;
    print "Press the \"back\" button, fix the problem and try again.";
    print $query->end_html();
    exit;
}

# Routine to convert text into an HTML version, but with hyperlinks rendered.
sub escapeHTML($$) {
    my ($self, $text) = @_;

    my $query = $self->{query};

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

1;
