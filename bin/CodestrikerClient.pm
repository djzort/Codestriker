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
#      email_event => 0,
#      topic_text => "Here is some text\nHere is some\n\nMore and more...\n"});
#
# $client->add_comment({
#      topic_id => 2138764,
#      file_number => 2,
#      file_line => 234,
#      file_new => 1,
#      email => 'david.sitsky@gmail.com',
#      cc => 'fred@email.com, barney@email.com',
#      comment_text => 'Here is a new comment'});

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
		    email_event => $params->{email_event},
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
    print STDERR "Failed to create topic, response: $response_content\n" if !(defined $rc) || $rc == 0;
    return defined $rc && $rc ? $1 : undef;
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

# Add a new comment to an existing topic.
sub add_comment {
    my ($self, $params) = @_;

    # Perform the HTTP Post.
    my $ua = new LWP::UserAgent;
    my $content = [ action => 'submit_comment',
                    line => $params->{file_line},
                    topic => $params->{topic_id},
                    fn => $params->{file_number},
                    new => $params->{file_new},
                    email => $params->{email},
                    comment_cc => $params->{cc},
                    comments => $params->{comment_text},
                    format => 'xml' ];
    my $response =
	$ua->request(HTTP::Request::Common::POST($self->{url},
						 Content_Type => 'form-data',
						 Content => $content));

    # Indicate if the operation was successful.
    my $response_content = $response->content;

    my $rc = $response_content =~ /\<result\>OK\<\/result\>/i;
    print STDERR "Failed to add comment, response: $response_content\n" if !(defined $rc) || $rc == 0;
    return defined $rc && $rc ? 1 : undef;
}

1;
