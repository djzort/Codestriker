###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Collection of routines for building codestriker URLs.

package Codestriker::Http::UrlBuilder;

use strict;

# Constants for different viewing file modes - set by the type CGI parameter.
$UrlBuilder::OLD_FILE = 0;
$UrlBuilder::NEW_FILE = 1;
$UrlBuilder::BOTH_FILES = 2;

# Constructor for this class.
sub new($$) {
    my ($type, $query) = @_;
    my $self = {};
    $self->{query} = $query;

    # Determine what prefix is required when using relative URLs.
    # Unfortunately, Netcsape 4.x does things differently to everyone
    # else.
    my $browser = $ENV{'HTTP_USER_AGENT'};
    $self->{url_prefix} = "";
    if (defined $browser && $browser =~ m%^Mozilla/(\d)% && $1 <= 4) {
	$self->{url_prefix} = $query->url(-relative=>1);
    }

    # Check if the HTML files are accessible vi another URL (required for
    # sourceforge deployment).  Check $Codestriker::codestriker_css.
    my $htmlurl;
    if (defined $Codestriker::codestriker_css &&
	$Codestriker::codestriker_css ne "") {
	$htmlurl = $Codestriker::codestriker_css;
	$htmlurl =~ s/\/codestriker\.css//;
    }
    else {
	# Standard Codestriker deployment.
	$htmlurl = $query->url();
	$htmlurl =~ s/codestriker\/codestriker\.pl/codestrikerhtml/;
    }
    $self->{htmldir} = $htmlurl;

    return bless $self, $type;
}

# Create the URL for viewing a topic with a specified tabwidth.
sub view_url_extended ($$$$$$$$$$) {
    my ($self, $topic, $line, $mode, $tabwidth, $email, $prefix,
	$updated, $brmode, $fview) = @_;
    
    return ($prefix ne "" ? $prefix : $self->{query}->url()) .
	"?topic=$topic&action=view" .
	($updated ? "&updated=$updated" : "") .
	((defined $tabwidth && $tabwidth ne "") ? "&tabwidth=$tabwidth" : "") .
	((defined $mode && $mode ne "") ? "&mode=$mode" : "") .
	((defined $brmode && $brmode ne "") ? "&brmode=$brmode" : "") .
	((defined $fview && $fview ne "") ? "&fview=$fview" : "") .
	((defined $email && $email ne "") ? "&email=$email" : "") .
	($line != -1 ? "#${line}" : "");
}

# Create the URL for viewing a topic.
sub view_url ($$$$$$) {
    my ($self, $topic, $line, $mode, $brmode, $fview) = @_;
    if (!(defined $mode)) { $mode = $Codestriker::default_topic_create_mode; }
    if (!(defined $brmode)) { $brmode = $Codestriker::default_topic_br_mode; }
    if (!(defined $fview)) { $fview = $Codestriker::default_file_to_view; }
    return $self->view_url_extended($topic, $line, $mode, "", "", "",
				    undef, $brmode, $fview);
}

# Create the URL for downloading the topic text.
sub download_url ($$) {
    my ($self, $topic) = @_;
    return $self->{query}->url() . "?action=download&topic=$topic";
}

# Create the URL for creating a topic.
sub create_topic_url ($$) {
    my ($self, $obsoletes) = @_;
    return $self->{query}->url() . "?action=create" .
	(defined $obsoletes ? "&obsoletes=$obsoletes" : "");
}	    

# Create the URL for editing a topic.
sub edit_url ($$$$$$$) {
    my ($self, $filenumber, $line, $new, $topic, $context,
	$anchor, $prefix) = @_;
    return ($prefix ne "" ? $prefix : $self->{url_prefix}) .
	"?fn=$filenumber&line=$line&new=$new&topic=$topic&action=edit" .
	((defined $anchor && $anchor ne "") ? "&a=$anchor" : "") .
	((defined $context && $context ne "") ? "&context=$context" : "");
}

# Create the URL for viewing a new file.
sub view_file_url ($$$$$$$) {
    my ($self, $topic, $filenumber, $new, $line, $mode, $parallel) = @_;
    if (!(defined $mode)) { $mode = $Codestriker::default_topic_create_mode; }
    return $self->{url_prefix} . "?action=view_file&fn=$filenumber&" .
	"topic=$topic&new=$new&mode=$mode&parallel=$parallel#$filenumber|$line|$new";
}

# Create the URL for the search page.
sub search_url ($) {
    my ($self) = @_;
    return $self->{query}->url() . "?action=search";
}

# Create the URL for the documentation page.
sub doc_url ($) {
    my ($self) = @_;
    return $self->{htmldir};
}

# Create the URL for listing the topics (and topic search). See
# _list_topics_url for true param list.
sub list_topics_url ($$$$$$$$$$$\@\@$) {
    my ($self) = @_;

    shift @_; # peal off self.

    return $self->_list_topics_url("list_topics",@_);
}

# Create the URL for listing the topics (and topic search) via RSS. See
# _list_topics_url for true param list.
sub list_topics_url_rss ($$$$$$$$$$$\@\@$) {
    my ($self) = @_;

    shift @_; # peal off self.

    return $self->_list_topics_url("list_topics_rss",@_);
}

# Create the URL for listing the topics.
sub _list_topics_url ($$$$$$$$$$$$\@\@$) {
    my ($self, $action,$sauthor, $sreviewer, $scc, $sbugid, $stext,
	$stitle, $sdescription, $scomments, $sbody, $sfilename,
	$state_array_ref, $project_array_ref, $content) = @_;

    my $sstate = defined $state_array_ref ? (join ',', @$state_array_ref) : "";
    my $sproject = defined $project_array_ref ?
	(join ',', @$project_array_ref) : "";
    return $self->{query}->url() . "?action=$action" .
	($sauthor ne "" ? "&sauthor=$sauthor" : "") .
	($sreviewer ne "" ? "&sreviewer=$sreviewer" : "") .
	($scc ne "" ? "&scc=$scc" : "") .
	($sbugid ne "" ? "&sbugid=$sbugid" : "") .
	($stext ne "" ? "&stext=" . CGI::escape($stext) : "") .
	($stitle ne "" ? "&stitle=$stitle" : "") .
	($sdescription ne "" ? "&sdescription=$sdescription" : "") .
	($scomments ne "" ? "&scomments=$scomments" : "") .
	($sbody ne "" ? "&sbody=$sbody" : "") .
	($sfilename ne "" ? "&sfilename=$sfilename" : "") .
	($sstate ne "" ? "&sstate=$sstate" : "") .
	($sproject ne "" ? "&sproject=$sproject" : "") .
	(defined $content && $content ne "" ? "&content=$content" : "");
}


# Construct a URL for editing a specific project.
sub edit_project_url ($$) {
    my ($self, $projectid) = @_;

    return $self->{query}->url() . "?action=edit_project&projectid=$projectid";
}

# Construct a URL for listing all projects.
sub list_projects_url ($) {
    my ($self) = @_;

    return $self->{query}->url() . "?action=list_projects";
}

# Construct a URL for creating a project.
sub create_project_url ($) {
    my ($self) = @_;

    return $self->{query}->url() . "?action=create_project";
}

# Create the URL for viewing comments.
sub view_comments_url ($$) {
    my ($self, $topic) = @_;

    return $self->{query}->url() . "?action=list_comments&topic=$topic";
}

# Create the URL for viewing the topic properties.
sub view_topic_properties_url ($$) {
    my ($self, $topic) = @_;

    return $self->{query}->url() .
	"?action=view_topic_properties&topic=$topic";
}

# Create the URL for viewing the topic metrics.
sub view_topicinfo_url ($$) {
    my ($self, $topic) = @_;

    return $self->{query}->url() . "?action=viewinfo&topic=$topic";
}

sub metric_report_url {
    my ($self) = @_;

    return $self->{query}->url() . "?action=metrics_report";
}

sub metric_report_download_raw_data {
    my ($self) = @_;

    return $self->{query}->url() . "?action=metrics_download";
}

1;
