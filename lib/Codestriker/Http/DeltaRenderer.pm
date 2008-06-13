###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Object for handling the computation of a delta for displaying to HTML.

package Codestriker::Http::DeltaRenderer;

use strict;

use Codestriker::Http::HtmlEntityLineFilter;
use Codestriker::Http::TabToNbspLineFilter;
use Codestriker::Http::LineBreakLineFilter;
use Codestriker::Http::LxrLineFilter;

# Constructor.
sub new {
    my ($type, $topic, $comments, $deltas, $query, $mode, $brmode,
		$tabwidth, $repository) = @_;

    my $self = {};
    $self->{topic} = $topic;
    $self->{comments} = $comments;
    $self->{deltas} = $deltas;
    $self->{query} = $query;
    $self->{mode} = $mode;
    $self->{brmode} = $brmode;
    $self->{tabwidth} = $tabwidth;

    # Build a hash from filenumber|fileline|new -> comment array, so that
    # when rendering, lines can be coloured appropriately.  Also build a list
    # of what points in the review have a comment.  Also record a mapping
    # from filenumber|fileline|new -> the comment number.
    my %comment_hash = ();
    my @comment_locations = ();
    my %comment_location_map = ();
    for (my $i = 0; $i <= $#$comments; $i++) {
	my $comment = $$comments[$i];
	my $key = $comment->{filenumber} . "|" . $comment->{fileline} . "|" .
	    $comment->{filenew};
	if (! exists $comment_hash{$key}) {
	    push @comment_locations, $key;
	    $comment_location_map{$key} = $#comment_locations;
	}
        push @{ $comment_hash{$key} }, $comment;
    }
    $self->{comment_hash} = \%comment_hash;
    $self->{comment_locations} = \@comment_locations;
    $self->{comment_location_map} = \%comment_location_map;

    # Record list of line filter objects to apply to each line of code.
    # Setup some default filters.
    my $lxr_config = defined $repository ?
		$Codestriker::lxr_map->{$repository->toString()} : undef;
    
    @{$self->{line_filters}} = ();
    push @{$self->{line_filters}}, Codestriker::Http::HtmlEntityLineFilter->new();
    push @{$self->{line_filters}}, Codestriker::Http::TabToNbspLineFilter->new($tabwidth);
    push @{$self->{line_filters}}, Codestriker::Http::LineBreakLineFilter->new($brmode);
    if (defined $lxr_config) {
	    push @{$self->{line_filters}}, Codestriker::Http::LxrLineFilter->new($lxr_config);
    }

    bless $self, $type;
}

# Add a line filter to this delta-renderer, which will be called for each
# line that is to be rendered.
sub add_line_filter
{
    my ($self, $line_filter) = @_;
    push @{$self->{line_filters}}, $line_filter;
}

# Render $text with the appropriate anchor attributes set for
# displaying any existing comments and a link for adding new ones.
sub comment_link
{
    my ($self, $filenumber, $line, $new, $text) = @_;

    # Determine the anchor and edit URL for this line number.
    my $anchor = "$filenumber|$line|$new";
    my $edit_url = "javascript:eo('$filenumber','$line','$new')";

    # Set the anchor to this line number.
    my $params = {};
    $params->{name} = $anchor;

    # Only set the href attribute if the comment is in open state.
    if (!Codestriker::topic_readonly($self->{topic}->{topic_state})) {
	    $params->{href} = $edit_url;
    }

    # If a comment exists on this line, set span and the overlib hooks onto
    # it.
    my %comment_hash = %{ $self->{comment_hash} };
    my %comment_location_map = %{ $self->{comment_location_map} };
    my $comment_number = undef;
    my $query = $self->{query};
    if (exists $comment_hash{$anchor}) {
	# Determine what comment number this anchor refers to.
	$comment_number = $comment_location_map{$anchor};
	$text = $query->span({-id=>"c$comment_number"}, "") .
	    $query->span({-class=>"com"}, $text);

	# Determine what the next comment in line is.
	my $index = -1;
	my @comment_locations = @{ $self->{comment_locations} };
	for ($index = 0; $index <= $#comment_locations; $index++) {
	    last if $anchor eq $comment_locations[$index];
	}

	$params->{onmouseover} =
	    "return overlib(comment_text[$index],STICKY,DRAGGABLE,ALTCUT);";
	$params->{onmouseout} = "return nd();";
    } else {
	$text = $query->span({-class=>"nocom"}, $text);
    }

    return $query->a($params, $text);
}

# Go through all of the deltas, and append a line array for each delta with
# enough information to render it easily.
sub annotate_deltas
{
    my ($self) = @_;

    foreach my $delta (@{ $self->{deltas} }) {

	# Now process the text so that the display code has minimal work to do.
	# Also apply appropriate transformations to the line as required.
	my @diff_lines = split /\n/, $delta->{text};
	my $old_linenumber = $delta->{old_linenumber};
	my $new_linenumber = $delta->{new_linenumber};
	@{$self->{lines}} = ();
	@{$self->{diff_old_lines}} = ();
	@{$self->{diff_old_lines_numbers}} = ();
	@{$self->{diff_new_lines}} = ();
	@{$self->{diff_new_lines_numbers}} = ();
	$self->{current_filename} = "";
	for (my $i = 0; $i <= $#diff_lines; $i++) {
	    my $data = $diff_lines[$i];

	    if ($data =~ /^\-(.*)$/o) {
		# Line corresponding to old code.
		push @{ $self->{diff_old_lines} }, $1;
		push @{ $self->{diff_old_lines_numbers} }, $old_linenumber;
		$old_linenumber++;
	    } elsif ($data =~ /^\+(.*)$/o) {
		# Line corresponding to new code.
		push @{ $self->{diff_new_lines} }, $1;
		push @{ $self->{diff_new_lines_numbers} }, $new_linenumber;
		$new_linenumber++;
	    } elsif ($data =~ /^\\/) {
		# A diff comment such as "No newline at end of file" - ignore it.
	    } else {
		# Line corresponding to both sides. Strip the first space off
		# the diff for proper alignment.
		$data =~ s/^\s//;
		
		# Render what has been currently recorded.
		$self->_render_changes($delta->{filenumber});
		
		# Now that the diff changeset has been rendered, remove the state data.
		@{$self->{diff_old_lines}} = ();
		@{$self->{diff_old_lines_numbers}} = ();
		@{$self->{diff_new_lines}} = ();
		@{$self->{diff_new_lines_numbers}} = ();

		# Now render the line which is present on both sides.
		my $line = {};
		$data = $self->_apply_line_filters($data);
		my $data_class =
		    $self->{mode} == $Codestriker::COLOURED_MODE ? "n" : "msn";
		$line->{old_data} = $data;
		$line->{old_data_line} =
		    $self->comment_link($delta->{filenumber}, $old_linenumber,
					0, $old_linenumber);
		$line->{old_data_class} = $data_class;
		$line->{new_data} = $data;
		$line->{new_data_line} =
		    $self->comment_link($delta->{filenumber}, $new_linenumber,
					1, $new_linenumber);
		$line->{new_data_class} = $data_class;
		push @{$self->{lines}}, $line;
		$old_linenumber++;
		$new_linenumber++;
	    }

	    # Check if the delta corresponds to a new file.  This is true
	    # if there is only one delta for the whole file, there are no
	    # old lines, and the diff strarts at 0,1.
	    $delta->{new_file} = 
		$delta->{only_delta_in_file} &&	$old_linenumber == 0 &&
		$delta->{old_linenumber} == 0 && $delta->{new_linenumber} == 1;
	    if ($delta->{new_file}) {
		$delta->{new_file_class} =
		    $self->{mode} == $Codestriker::COLOURED_MODE ? "n" : "msn";
	    }
	}

	# Render any remaining diff segments.
	$self->_render_changes($delta->{filenumber});

	# Store the processed lines with the delta object for rendering.
	@{$delta->{lines}} = @{$self->{lines}};

	if ($self->{current_filename} ne $delta->{filename}) {
	    # Keep track of the current filename being processed.
	    $self->{current_filename} = $delta->{filename};
	}
    }
}

# Annotate any accumlated diff changes.
sub _render_changes
{
    my ($self, $filenumber) = @_;

    # Determine the class to use for displaying the comments.
    my ($old_col, $old_notpresent_col, $new_col, $new_notpresent_col);
    if (@{$self->{diff_new_lines}} > 0 && @{$self->{diff_old_lines}} > 0) {
	# Lines have been added and removed.
	if ($self->{mode} == $Codestriker::COLOURED_MODE) {
	    $old_col = "c";
	    $old_notpresent_col = "cb";
	    $new_col = "c";
	    $new_notpresent_col = "cb";
	} else {
	    $old_col = "msc";
	    $old_notpresent_col = "mscb";
	    $new_col = "msc";
	    $new_notpresent_col = "mscb";
	}
    } elsif (@{$self->{diff_new_lines}} > 0 && @{$self->{diff_old_lines}} == 0) {
	# New lines have been added.
	if ($self->{mode} == $Codestriker::COLOURED_MODE) {
	    $old_col = "a";
	    $old_notpresent_col = "ab";
	    $new_col = "a";
	    $new_notpresent_col = "ab";
	} else {
	    $old_col = "msa";
	    $old_notpresent_col = "msab";
	    $new_col = "msa";
	    $new_notpresent_col = "msab";
	}
    } else {
	# Lines have been removed.
	if ($self->{mode} == $Codestriker::COLOURED_MODE) {
	    $old_col = "r";
	    $old_notpresent_col = "rb";
	    $new_col = "r";
	    $new_notpresent_col = "rb";
	} else {
	    $old_col = "msr";
	    $old_notpresent_col = "msrb";
	    $new_col = "msr";
	    $new_notpresent_col = "msrb";
	}
    }
    
    my ($old_data, $new_data, $old_data_line, $new_data_line);
    while (@{$self->{diff_old_lines}} > 0 || @{$self->{diff_new_lines}} > 0) {
	
	# Retrieve the next lines which were removed (if any).
	if (@{$self->{diff_old_lines}} > 0) {
	    $old_data = shift @{$self->{diff_old_lines}};
	    $old_data_line = shift @{$self->{diff_old_lines_numbers}};
	} else {
	    undef($old_data);
	    undef($old_data_line);
	}
	
	# Retrieve the next lines which were added (if any).
	if (@{$self->{diff_new_lines}} > 0) {
	    $new_data = shift @{$self->{diff_new_lines}};
	    $new_data_line = shift @{$self->{diff_new_lines_numbers}};
	} else {
	    undef($new_data);
	    undef($new_data_line);
	}
	
	# Set the colours to use appropriately depending on what is defined.
	my $render_old_colour = $old_col;
	my $render_new_colour = $new_col;
	if (defined $old_data && ! defined $new_data) {
	    $render_new_colour = $new_notpresent_col;
	} elsif (! defined $old_data && defined $new_data) {
	    $render_old_colour = $old_notpresent_col;
	}
	
	my $line = {};
	if (defined $old_data) {
	    $line->{old_data} = $self->_apply_line_filters($old_data);
	    $line->{old_data_line} =
		$self->comment_link($filenumber, $old_data_line, 0, $old_data_line);
	}
	$line->{old_data_class} = $render_old_colour;
	if (defined $new_data) {
	    $line->{new_data} = $self->_apply_line_filters($new_data);
	    $line->{new_data_line} =
		$self->comment_link($filenumber, $new_data_line, 1, $new_data_line);
	}
	$line->{new_data_class} = $render_new_colour;
	push @{$self->{lines}}, $line;
    }

    # Apply all of the line filters to the line of text supplied.
    sub _apply_line_filters {
	my ($self, $text) = @_;

	# TODO: perform syntax highlighting.
	foreach my $line_filter (@{$self->{line_filters}}) {
	    $text = $line_filter->filter($text);
	}
	    
	# Unconditionally add a &nbsp; at the start for better alignment.
	# Fix so count isn't stuffed.
	return "&nbsp;" . $text;
    }
}

1;
