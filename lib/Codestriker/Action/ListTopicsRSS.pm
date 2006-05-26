###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying a list of topics.

package Codestriker::Action::ListTopicsRSS;

use strict;
use Codestriker::Http::Template;
use Codestriker::Model::Topic;
use XML::RSS;

# If the input is valid, list the appropriate topics.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check if this action is allowed.
    if ($Codestriker::allow_searchlist == 0) {
	$http_response->error("This function has been disabled");
    }

    # Query the model for the specified data.

    my $mode = $http_input->get('mode');

    my ( $sauthor, $sreviewer, $scc, $sbugid,
         $sstate, $sproject, $stext,
         $stitle, $sdescription,
	 $scomments, $sbody, $sfilename,
         $sort_order) = Codestriker::Action::ListTopics::get_topic_list_query_params($http_input);

    # Query the model for the specified data.
    my @topics = Codestriker::Model::Topic->query($sauthor, $sreviewer, $scc, $sbugid,
				     $sstate, $sproject, $stext,
				     $stitle, $sdescription,
				     $scomments, $sbody, $sfilename,
                                     $sort_order);
   
    # Display the data, with each topic title linked to the view topic screen.
    # If only a single project id is being searched over, set that id in the
    # cookie.
    my @project_ids = ();
    if ($sproject ne "") {
	@project_ids = split ',', $sproject;
    }

    # Print the header. Should really be application/rss+xml, except when 
    # people click on the link they get a pop-up asking for an application
    # that knows how to show application/rss+xml. Very confusing, so we 
    # will just say it is xml, (which it is of coarse). The link tag in
    # the template lists it as application/rss+xml.
    print $query->header(-type=>'application/xml');

    # Obtain a new URL builder object.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    my $rss = new XML::RSS(version => '2.0');

    my $this_url  = 
	$url_builder->list_topics_url_rss($sauthor, $sreviewer, $scc, $sbugid,
				      $stext, $stitle,
				      $sdescription, $scomments,
				      $sbody, $sfilename,
				      [ split ',', $sstate] , \@project_ids);


    $rss->channel(title=>$Codestriker::title, language=>"en",link=>$this_url);

    # For each topic, collect all the reviewers, CC, and bugs, and display it
    # as a row in the table.  Each bug should be linked appropriately. 
    foreach my $topic (@topics) {

        # do the easy stuff first, 1 to 1 mapping into the template.
	my $link =
	    $url_builder->view_url($topic->{topicid}, -1, $mode,
				   $Codestriker::default_topic_br_mode);

	my $comment_link = $url_builder->view_comments_url($topic->{topicid});

	my $description = $topic->{description};
	my $title = $topic->{title};

        # Change to 1 to send out the list of files changes in the RSS description.
        if (0) {
            my (@filenames, @revisions, @offsets, @binary);
            $topic->get_filestable(
    		        \@filenames,
                        \@revisions,
                        \@offsets,
                        \@binary);

            $description .= "<p>" . join( "\n",@filenames);
        }

        my @comments = $topic->read_comments();

        $description .= "<p>Comments: " . scalar( @comments ) . ", ";
        $description .= "State: " . $topic->{topic_state} . ", ";
        $description .= "Author: " . Codestriker->filter_email($topic->{author});

        $rss->add_item(
            title=>$title, 
            permaLink=>$link, 
            description=>$description,
            author=> Codestriker->filter_email($topic->{author}),
            pubDate=>Codestriker->format_short_timestamp($topic->{creation_ts}),
            category=>$topic->{project_name},
            comments=>$comment_link
            );

    }

    print $rss->as_string();
}

1;
