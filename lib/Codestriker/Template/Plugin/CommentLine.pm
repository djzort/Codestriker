package Codestriker::Template::Plugin::CommentLine;

# Template toolkit plugin module for outputting the anchor text
# for a specific line.

use Template::Plugin::Filter;
use Codestriker;
use Codestriker::Http::UrlBuilder;

use base qw( Template::Plugin::Filter );

# Indicate that the filter should be re-created on each filter call.
our $DYNAMIC = 1;

sub filter {
    my ($self, $text, $args, $conf) = @_;

    $conf = $self->merge_config($conf);

    # Constructor parameters.
    my $query = $conf->{query};
    my $comment_hash = %{ $conf->{comment_hash} };
    my $comment_location_map = %{ $conf->{comment_location_map} };
    my $mode = $conf->{mode};

    # Filter parameters.
    my $filenumber = $conf->{filenumber};
    my $line = $conf->{line};
    my $new = $conf->{new};

    # Determine the comment class to use.
    my $comment_class = $mode eq 'coloured' ? 'com' : 'smscom';
    my $no_comment_class = $mode eq 'coloured' ? 'nocom' : 'smsnocom';

    # Determine the anchor and edit URL for this line number.
    my $anchor = "$filenumber|$line|$new";
    my $edit_url = "javascript:eo('$filenumber','$line','$new')";

    # Set the anchor to this line number.
    my $params = {};
    $params->{name} = $anchor;

    # Only set the href attribute if the comment is in open state.
    if (!Codestriker::topic_readonly($self->{topic_state})) {
	$params->{href} = $edit_url;
    }

    # If a comment exists on this line, set span and the overlib hooks onto
    # it.
    my $comment_number = undef;
    if (exists $comment_hash{$anchor}) {
	# Determine what comment number this anchor refers to.
	$comment_number = $comment_location_map{$anchor};

	if (defined $comment_class) {
	    $text = $query->span({-id=>"c$comment_number"}, "") .
		$query->span({-class=>$comment_class}, $text);
	}

	# Determine what the next comment in line is.
	my $index = -1;
	my @comment_locations = @{ $self->{comment_locations} };
	for ($index = 0; $index <= $#comment_locations; $index++) {
	    last if $anchor eq $comment_locations[$index];
	}

	$params->{onmouseover} = "return overlib(comment_text[$index],STICKY,DRAGGABLE,ALTCUT);";
	$params->{onmouseout} = "return nd();";
    } else {
	if (defined $no_comment_class) {
	    $text = $query->span({-class=>$no_comment_class}, $text);
	}
    }

    return $query->a($params, $text);
}

1;
