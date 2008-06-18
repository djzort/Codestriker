###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Line filter for highlighting code into xhtml using highlight, available from
#  http://www.andre-simon.de/.

package Codestriker::Http::HighlightLineFilter;

use strict;

use File::Temp qw/ tempfile /;

use Codestriker::Http::LineFilter;

@Codestriker::Http::HighlightLineFilter::ISA =
    ("Codestriker::Http::LineFilter");

# Take the desired tabwidth as a parameter.
sub new {
    my ($type, $highlight, $tabwidth) = @_;

    my $self = Codestriker::Http::LineFilter->new();
    $self->{highlight} = $highlight;
    $self->{tabwidth} = $tabwidth;

    return bless $self, $type;
}

# Convert tabs to the appropriate number of &nbsp; entities.
sub _filter {
    my ($self, $text, $extension) = @_;

	# Create a temporary file which will contain the delta text to highlight.
	my ($input_text_fh, $input_filename) = tempfile(SUFFIX => $extension);
	print $input_text_fh $text;
	close $input_text_fh;
	
	# Execute the highlight command, and store the stdout into $read_data.
	my $read_data = "";	
    my $read_stdout_fh = new FileHandle;
    open($read_stdout_fh, '>', \$read_data);
    my @args = ();
    push @args, '-i';
    push @args, $input_filename;
    push @args, '--xhtml';
    push @args, '-f';
    push @args, '-t';
    push @args, $self->{tabwidth};
    Codestriker::execute_command($read_stdout_fh, undef, $self->{highlight}, @args);
    if ($read_data eq "") {
    	# Assume this occurred because the filename was an unsupported type.
    	# Just return the text appropriately encoded for html output.
    	$read_data = HTML::Entities::encode($text);
    }
    
    # Delete the temp file.
    unlink $input_filename;
    
    return $read_data;
}

# Convert tabs to the appropriate number of &nbsp; entities.
sub filter {
    my ($self, $delta) = @_;
    
    # Determine the filename extension so the highlighter knows what language
    # to apply highlighting to.  Handle CVS files which might end in ,v.
    my $extension = ".txt";
    if ($delta->{filename} =~ /^.*(\..*),v$/o || $delta->{filename} =~ /^.*(\..*)$/o) {
    	$extension = $1;
    }
    
    $delta->{diff_old_lines} = $self->_filter($delta->{diff_old_lines}, $extension);
    $delta->{diff_new_lines} = $self->_filter($delta->{diff_new_lines}, $extension);
}

1;
