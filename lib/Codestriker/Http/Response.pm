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
use HTML::Entities ();

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
sub generate_header {
    
    my ($self, %params) = @_;

    my $topic = "";
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

    # Some screens don't have $topic set, if so, set it to a blank value.
    $topic = "" if ! defined($topic);

    # Set the cookie in the HTTP header for the $email, $cc, $reviewers and
    # $tabwidth parameters.
    my %cookie = ();

    if (!exists $params{email} || $params{email} eq "") {
	$email = Codestriker::Http::Cookie->get_property($query, 'email');
    }
    else {
        $email = $params{email};
    }

    if (!exists $params{reviewers} || $params{reviewers} eq "") {
	$reviewers = Codestriker::Http::Cookie->get_property($query,
							     'reviewers');
    }
    else {
        $reviewers = $params{reviewers};
    }

    if (!exists $params{cc} || $params{cc} eq "") {
	$cc = Codestriker::Http::Cookie->get_property($query, 'cc');
    }
    else {
        $cc = $params{cc};
    }

    if (!exists $params{tabwidth} || $params{tabwidth} eq "") {
	$tabwidth = Codestriker::Http::Cookie->get_property($query,
							    'tabwidth');
    }
    else {
        $tabwidth = $params{tabwidth};
    }

    if (!exists $params{mode} || $params{mode} eq "") {
	$mode = Codestriker::Http::Cookie->get_property($query, 'mode');
    }
    else {
        $mode = $params{mode};
    }

    if (!exists $params{repository} || $params{repository} eq "") {
	$repository = Codestriker::Http::Cookie->get_property($query,
							     'repository');
    }
    else {
        $repository = $params{repository};
    }

    if (!exists $params{projectid} || $params{projectid} eq "") {
	$projectid = Codestriker::Http::Cookie->get_property($query,
							     'projectid');
    }
    else {
        $projectid = $params{projectid};
    }

    if (!exists $params{topicsort} || $params{topicsort} eq "") {
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
				 -vary=>'Accept-Encoding');
	} else {
	    print $query->header(-cookie=>$cookie_obj,
				 -expires=>'+1d',
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
    $title = HTML::Entities::encode($title);

    # Generate the URL to the codestriker CSS file.
    my $codestriker_css;
    if ($Codestriker::codestriker_css ne "") {
	$codestriker_css = $Codestriker::codestriker_css;
    } else {
	$codestriker_css = $query->url();
	$codestriker_css =~ s/codestriker\/codestriker\.pl/codestrikerhtml\/codestriker\.css/;
    }

    my $overlib_js = $codestriker_css;
    $overlib_js =~ s/codestriker.css/overlib.js/;
    my $xbdhtml_js = $codestriker_css;
    $xbdhtml_js =~ s/codestriker.css/xbdhtml.js/;
    my $codestriker_js = $codestriker_css;
    $codestriker_js =~ s/codestriker.css/codestriker.js/;

    # Print the basic HTML header header, with the inclusion of the scripts.
    print '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">';
    print "\n";
    print '<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US">';
    print "\n";
    print "<head><title>$title</title>\n";
    print "<base href=\"$query->url()\"/>\n";
    print "<link rel=\"stylesheet\" type=\"text/css\" href=\"$codestriker_css\" />\n";
    print "<script src=\"$overlib_js\" type=\"text/javascript\"></script>\n";
    print "<script src=\"$xbdhtml_js\" type=\"text/javascript\"></script>\n";
    print "<script src=\"$codestriker_js\" type=\"text/javascript\"></script>\n";

    # Write a comment indicating if this was compressed or not.
    $self->{output_compressed} = $output_compressed;
    print "\n<!-- Source was" . (!$output_compressed ? " not" : "") .
	" sent compressed. -->\n";
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
    if (! $self->{generated_header}) {
	print $query->header, $query->start_html(-title=>'Codestriker error',
						 -bgcolor=>'white');
    }

    print $query->p, "<FONT COLOR='red'>$error_message</FONT>", $query->p;
    print $query->end_html();

    $self->generate_footer();
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
