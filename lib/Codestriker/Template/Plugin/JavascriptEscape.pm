package Codestriker::Template::Plugin::JavascriptEscape;

# Simple template toolkit plugin module for escaping the appropriate
# characters within a javascript string.

use Template::Plugin::Filter;
use Codestriker;

use base qw( Template::Plugin::Filter );

sub filter {
    my ($self, $text) = @_;

    # Escape double and single quotes and backslashes.
    $text =~ s/\\/\\\\/g;
    $text =~ s/\"/\\\"/g;
    $text =~ s/\'/\\\'/g;
    
    return $text;
}

1;
