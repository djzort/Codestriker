###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Package for the creation and management of templates.

package Codestriker::Http::Template;

use strict;
use Template;

# Create a new template.
sub new($$) {
    my ($type, $name) = @_;

    my $self = {};
    $self->{name} = $name;
    $self->{template} =
	Template->new({
	    # Location of templates.
	    INCLUDE_PATH => "../template/en/custom:../template/en/default" ,

	    # Remove white-space before template directives
	    # (PRE_CHOMP) and at the beginning and end of templates
	    # and template blocks (TRIM) for better looking, more
	    # compact content.  Use the plus sign at the beginning #
	    # of directives to maintain white space (i.e. [%+
	    # DIRECTIVE %]).
	    PRE_CHOMP => 1,
	    TRIM => 1, 
	    
	    # Where to compile the templates.
	    COMPILE_DIR => 'data/'
	    });

    return bless $self, $type;
}

# Return the template associated with this object.
sub get_template($) {
    my ($self) = @_;

    return $self->{template};
}

# Process the template.
sub process($$) {
    my ($self, $vars) = @_;

    $self->{template}->process($self->{name} . ".html.tmpl", $vars) ||
	die $self->{template}->error();
}

1;
    
