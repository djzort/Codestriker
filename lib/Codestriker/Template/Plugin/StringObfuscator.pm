package Codestriker::Template::Plugin::StringObfuscator;

# Simple template toolkit plugin module for modifying the string
# into a more obfuscated form which spam harvesters can't use for
# nabbing email addresses.

use Template::Plugin::Filter;
use Codestriker;

use base qw( Template::Plugin::Filter );

sub filter {
    my ($self, $text) = @_;

    my $length = length($text);
    my $result = "";
    for (my $i = 0; $i < $length; $i++) {
	my $char = substr $text, $i, 1;
	$result .= "\"" unless $i == 0;
	$result .= "$char";
	$result .= "\"+" unless $i == $length-1;
    }

    return $result;
}

1;
