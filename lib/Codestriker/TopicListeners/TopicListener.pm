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

sub new {
    my $type = shift;
    my $self = {};
    return bless $self, $type;
}

sub topic_create($$) { 
    my ($self, $user, $topic) = @_;
    
    # Default version of function that does nothing, and allowed the
    # event to continue.

    return '';    
}

sub topic_changed($$$) {
    my ($self, $user, $topic_orig, $topic) = @_;

    # Default version of function that does nothing, and allowed the
    # event to continue.
    
    return '';    
}

sub topic_viewed($$$) {
    my ($self, $user, $topic) = @_;

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

sub comment_state_change($$$$$) {
    my ($self, $user, $old_state_id, $topic, $comment) = @_;

    # Default version of function that does nothing, and allowed the
    # event to continue.
    
    return '';    
}

1;
