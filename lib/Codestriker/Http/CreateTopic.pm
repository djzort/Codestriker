###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Code for creating a topic non-interactively via HTTP.

package Codestriker::Http::CreateTopic;

use strict;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use File::Temp qw/ tempfile /;
use IO::Handle;

# Example usage.
#Codestriker::Http::CreateTopic->
#      doit({url => 'http://localhost.localdomain/codestriker/codestriker.pl',
#      topic_title => 'Automatic Topic from script',
#      topic_description => "Automatic Topic Description\nAnd more",
#      project_name => 'Project2',
#      repository => ':ext:sits@localhost:/home/sits/cvs',
#      bug_ids => '1',
#      email => 'sits',
#      reviewers => 'root',
#      topic_text => "Here is some text\nHere is some\n\nMore and more...\n"});

sub doit {
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
		    topic_file => [$tempfile_filename]];
    my $response =
	$ua->request(HTTP::Request::Common::POST($params->{url},
						 Content_Type => 'form-data',
						 Content => $content));

    # Indicate if the operation was successful.
    my $content = $response->content;
    my $rc = $content =~ /Topic URL: \<A HREF=\"(.*)\"/i;
    print STDERR "Failed to create topic, response: $content\n" if $rc == 0;
    return $rc ? $1 : undef;
}

1;
