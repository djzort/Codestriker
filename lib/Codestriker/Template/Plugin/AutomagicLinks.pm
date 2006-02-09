package Codestriker::Template::Plugin::AutomagicLinks;

# Simple template toolkit plugin module for automagically changing all
# URLs to be hyperlinked, and all text in the form "Bug \d+" to be changed
# to link with the associated bug record if a bugtracking system is
# registered with the system.

use Template::Plugin::Filter;
use Codestriker;

use base qw( Template::Plugin::Filter );

sub filter {
    my ($self, $text) = @_;
    
    # First handle any URL linking.
    my @words = split /(\s)/, $text;
    my $result = "";
    for (my $i = 0; $i <= $#words; $i++) {
	if ($words[$i] =~ /^([A-Za-z]+:\/\/.*[A-Za-z0-9_])(.*)$/o) {
	    # A URL, create a link to it.
	    $result .= "<A HREF=\"$1\">$1</A>$2";
	} else {
	    $result .= $words[$i];
	}
    }

    # If there is a link to a bug tracking system, automagically modify all
    # text of the form "[Bb]ug \d+" to a hyperlink for that bug record.
    if (defined $Codestriker::bugtracker && $Codestriker::bugtracker ne "") {
	$result =~ s/(\b)([Bb][Uu][Gg]\s*(\d+))(\b)/$1<A HREF="${Codestriker::bugtracker}$3">$1$2$4<\/A>/mg;
    }
    
    return $result;
}

1;
