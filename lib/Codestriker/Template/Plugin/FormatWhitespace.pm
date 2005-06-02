package Codestriker::Template::Plugin::FormatWhitespace;

# Simple template toolkit plugin module for formatting whitespace.

use Template::Plugin::Filter;
use Codestriker;

use base qw( Template::Plugin::Filter );

sub filter {
    my ($self, $text) = @_;

    # Get the tabwidth setting from the config.
    my $tabwidth = $self->{ _CONFIG }->{tabwidth};

    # Replace newlines with <br>s.
    $text =~ s/\n/<br>/mgo;

    # Replace consective spaces with &nbsp; entities.  Its important
    # start start with a leading space, so that the text can be
    # broken up when it appears inside a floating div or a table row.
    $text =~ s/ \s+/'&nbsp;' x (length($&)-1)/emgo;

    # Replace tabs.
    $text = Codestriker::Http::Render::tabadjust($tabwidth, $text, 1);
    
    return $text;
}

1;
