###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Collection of routines for building codestriker URLs.

package Codestriker::Http::UrlBuilder;

use strict;

# Prototypes.
sub new( $$ );
sub edit_url( $$$$$ );
sub download_url( $$ );
sub view_url( $$$$ );
sub view_url_extended( $$$$$$$ );
sub view_file_url( $$$$$$$ );
sub create_topic_url( $ );

# Constants for different viewing file modes - set by the type CGI parameter.
$UrlBuilder::OLD_FILE = 0;
$UrlBuilder::NEW_FILE = 1;
$UrlBuilder::BOTH_FILES = 2;

# Constructor for this class.
sub new($$) {
    my ($type, $query) = @_;
    my $self = {};
    $self->{query} = $query;

    # Determine what prefix is required wgen using relative URLs.
    # Unfortunately, Netcsape 4.x does things differently to everyone
    # else.
    my $browser = $ENV{'HTTP_USER_AGENT'};
    $self->{url_prefix} = ($browser =~ m%^Mozilla/(\d)% && $1 <= 4) ?
	$query->url(-relative=>1) : "";

    return bless $self, $type;
}

# Create the URL for viewing a topic with a specified tabwidth.
sub view_url_extended ($$$$$$$) {
    my ($self, $topic, $line, $mode, $tabwidth, $email, $prefix) = @_;
    return ($prefix ne "" ? $prefix : $self->{url_prefix}) .
	"?topic=$topic&action=view&mode=$mode" .
	((defined $tabwidth && $tabwidth ne "") ? "&tabwidth=$tabwidth" : "") .
	((defined $email && $email ne "") ? "&email=$email" : "") .
	($line != -1 ? "#${line}" : "");
}

# Create the URL for viewing a topic.
sub view_url ($$$$) {
    my ($self, $topic, $line, $mode) = @_;
    return $self->view_url_extended($topic, $line, $mode, "", "", "");
}

# Create the URL for downloading the topic text.
sub download_url ($$) {
    my ($self, $topic) = @_;
    return $self->{url_prefix} . "?action=download&topic=$topic";
}

# Create the URL for creating a topic.
sub create_topic_url ($) {
    my ($self) = @_;
    return $self->{query}->url() . "?action=create";
}	    

# Create the URL for editing a topic.
sub edit_url ($$$$$) {
    my ($self, $line, $topic, $context, $prefix) = @_;
    return ($prefix ne "" ? $prefix : $self->{url_prefix}) .
	"?line=$line&topic=$topic&action=edit" .
	    ((defined $context && $context ne "") ? "&context=$context" : "");
}

# Create the URL for viewing a new file.
sub view_file_url ($$$$$$$) {
    my ($self, $topic, $filename, $new, $line, $prefix, $mode) = @_;
    return $self->{url_prefix} . "?action=view_file&filename=$filename&" .
	"topic=$topic&mode=$mode&new=$new#" . "$prefix$line";
}

1;
