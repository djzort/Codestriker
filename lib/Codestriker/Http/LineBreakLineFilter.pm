###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Line filter for handling line-breaks.
# entities.

package Codestriker::Http::LineBreakLineFilter;

use strict;

use Codestriker::Http::LineFilter;

@Codestriker::Http::LineBreakLineFilter::ISA =
    ("Codestriker::Http::LineFilter");

# Take the linebreak mode as a parameter.
sub new {
    my ($type, $brmode, $inspan) = @_;

    my $self = Codestriker::Http::LineFilter->new();
    $self->{brmode} = $brmode;
    $self->{inspan} = $inspan;

    return bless $self, $type;
}

# Convert the spaces appropriately for line-breaking.
sub _filter {
    my ($self, $text) = @_;
    
    if ($self->{brmode} == $Codestriker::LINE_BREAK_ASSIST_MODE) {
    	# TODO: fix this for highlighted version.
		$text =~ s/^(\s+)/my $sp='';for(my $i=0;$i<length($1);$i++){$sp.='&nbsp;'}$sp;/ge;
    }
    else {
		if ($self->{inspan}) {
			my @lines = split /\n/, $text;
			my $result = "";
			foreach my $line (@lines) {
				$line =~ s/^( [ ]+)/('&nbsp;' x length($1))/eo;
				$line =~ s/(>[^<]*?)( [ ]+)/$1 . ('&nbsp;' x length($2))/eog;
				$result .= $line . "\n";
			} 
			$text = $result;
		} else {
			$text =~ s/ /&nbsp;/g;
		}     	
    }

    return $text;
}

# Convert the spaces appropriately for line-breaking.
sub filter {
    my ($self, $delta) = @_;
    
    $delta->{diff_old_lines} = $self->_filter($delta->{diff_old_lines});
    $delta->{diff_new_lines} = $self->_filter($delta->{diff_new_lines});
}

1;
