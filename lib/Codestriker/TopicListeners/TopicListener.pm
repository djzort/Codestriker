###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# This is a base class for all of the topic listeners objects. It
# provides an easy way to see what a listener is expected to
# implement, and it also provides stub functions for listeners that
# don't want to handle all of the events.
package Codestriker::TopicListeners::TopicListener;

use strict;
use warnings;

sub new {
    my $type = shift;
    my $self = {};
    return bless $self, $type;
}

sub topic_create($$) { 
    my ($self, $topic) = @_;
    
    # Default version of function that does nothing, and allowed the
    # event to continue.

    return '';    
}

sub topic_delete($$) {
    my ($self, $topic) = @_;

    # Default version of function that does nothing, and allowed the
    # event to continue.
        
    return '';     
}

sub topic_state_change($$$) {
    my ($self, $topic, $newstate) = @_;

    # Default version of function that does nothing, and allowed the
    # event to continue.
    
    return '';    
}

sub comment_create($$$) {
    my ($self, $topic, $comment) = @_;

    # Default version of function that does nothing, and allowed the
    # event to continue.
    
    return '';    
}

sub comment_state_change($$$) {
    my ($self, $topic, $comment, $newstate) = @_;

    # Default version of function that does nothing, and allowed the
    # event to continue.
    
    return '';    
}

1;
