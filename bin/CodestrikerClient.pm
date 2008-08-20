###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Code for interacting with a Codestriker server via HTTP.
#
# Example usage for creating a new Codestriker topic.
#
# my $client = CodestrikerClient->new('http://localhost.localdomain/codestriker/codestriker.pl');
# $client->create_topic({
#      topic_title => 'Automatic Topic from script',
#      topic_description => "Automatic Topic Description\nAnd more",
#      project_name => 'Project2',
#      repository => ':ext:sits@localhost:/home/sits/cvs',
#      bug_ids => '1',
#      email => 'sits',
#      reviewers => 'root',
#      topic_text => "Here is some text\nHere is some\n\nMore and more...\n"});

package CodestrikerClient;

use strict;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use File::Temp qw/ tempfile /;
use IO::Handle;

# Create a new CodestrikerClient object, which records the base URL of the server.
sub new {
    my ($type, $url) = @_;
    my $self = {};
    $self->{url} = $url;
    return bless $self, $type;
}

# Create a new topic.
sub create_topic {
    my ($self, $params) = @_;

    # Create a temporary file containing the topic text.
    my ($tempfile_fh, $tempfile_filename) = tempfile();
    $tempfile_fh->print($params->{topic_text});
    $tempfile_fh->flush;

    # Perform the HTTP Post.
    my $ua = new LWP::UserAgent;
    my $content = [ action => 'submit_new_topic',
		    topic_title => $params->{topic_title},
		    topic_description => $params->{topic_description},
		    project_name => $params->{project_name},
		    repository => $params->{repository},
		    bug_ids => $params->{bug_ids},
		    email => $params->{email},
		    reviewers => $params->{reviewers},
		    cc => $params->{cc},
		    topic_state => $params->{topic_state},
		    topic_file => [$tempfile_filename]];
    my $response =
	$ua->request(HTTP::Request::Common::POST($self->{url},
						 Content_Type => 'form-data',
						 Content => $content));

    # Remove the temporary file.
    unlink $tempfile_filename;

    # Indicate if the operation was successful.
    my $response_content = $response->content;
    my $rc = $response_content =~ /Topic URL: \<A HREF=\"(.*)\"/i;
    print STDERR "Failed to create topic, response: $response_content\n" if $rc == 0;
    return $rc ? $1 : undef;
}

# Retrieve the details of a topic in XML format
# Filtered based on a bugid
sub get_topics_xml {
    my ($self, $bugid, $author, $reviewer, $cc, $text) = @_;

    # Perform the HTTP Post.
    my $ua = new LWP::UserAgent;
    my $content = [ action => 'list_topics',
		    format => 'xml',
		    sbugid => $bugid,
		    sauthor => $author,
		    sreviewer => $reviewer,
		    scc => $cc,
		    stext => $text];

    my $response =
	$ua->request(HTTP::Request::Common::POST($self->{url},
						 Content_Type => 'form-data',
						 Content => $content));

    return $response->content;
}


1;
