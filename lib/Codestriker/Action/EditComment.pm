###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for adding a comment to a topic line.

package Codestriker::Action::EditComment;

use strict;
use Codestriker::Model::Topic;

# Create an appropriate form for adding a comment to a topic.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    # Obtain a new URL builder object.
    my $query = $http_response->get_query();
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Retrieve the appropriate input fields.
    my $line = $http_input->get('line');
    my $fn = $http_input->get('fn');
    my $new = $http_input->get('new');
    my $topicid = $http_input->get('topic');
    my $context = $http_input->get('context');
    my $email = $http_input->get('email');
    my $mode = $http_input->get('mode');
    my $tabwidth = $http_input->get('tabwidth');
    my $anchor = $http_input->get('a');
    my $fview = $http_input->get('fview');

    # Retrieve the appropriate topic details.
    my $topic = Codestriker::Model::Topic->new($topicid);

    # Retrieve the comment details for this topic.
    my @comments = $topic->read_comments();

    # Retrieve line-by-line versions of the description.
    my @document_description = split /\n/, $topic->{description};

    # Display the header of this page.
    $http_response->generate_header(topic=>$topic,
				    topic_title=>"Edit Comment: $topic->{title}",
				    email=>$email, 
    				    mode=>$mode,
				    tabwidth=>$tabwidth,
				    repository=>$Codestriker::repository_name_map->{$topic->{repository}}, 
				    reload=>0, cache=>0);

    # Create the hash for the template variables.
    my $vars = {};
    $vars->{'topic_title'} = $topic->{title};

    Codestriker::Action::ViewTopic::ProcessTopicHeader($vars, $topic,
						       $url_builder, $fview,
						       $tabwidth, 1, 0);

    my $view_topic_url = $url_builder->view_url(topicid => $topicid, projectid => $topic->{project_id},
                                                mode => $mode, fview => $fn, filenumber => $fn,
                                                new => $new, line => $line);
    my $view_comments_url = $url_builder->view_comments_url(topicid => $topicid,
                                                            projectid => $topic->{project_id});
    
    $vars->{'view_topic_url'} = $view_topic_url;
    $vars->{'view_comments_url'} = $view_comments_url;
    $vars->{'doc_url'} = $url_builder->doc_url();

    # Retrieve the context in question.  Allow the user to increase it
    # or decrease it appropriately.
    my $inc_context = ($context <= 0) ? 1 : $context*2;
    my $dec_context = ($context <= 0) ? 0 : int($context/2);
    my $inc_context_url =
	$url_builder->edit_url(filenumber => $fn, line => $line, new => $new,
	                       topicid => $topicid, projectid => $topic->{projectid},
			               context => $inc_context, anchor => $anchor);
    my $dec_context_url =
	$url_builder->edit_url(filenumber => $fn, line => $line, new => $new,
	                       topicid => $topicid, projectid => $topic->{projectid},
			               context => $dec_context, anchor => $anchor);
    $vars->{'inc_context_url'} = $inc_context_url;
    $vars->{'dec_context_url'} = $dec_context_url;
    $vars->{'context'} = "";
    if ($line != -1) {
	# Retrieve the context for a comment made against a specific line.
	my $delta = Codestriker::Model::Delta->get_delta($topicid, $fn,
							 $line, $new);

	my @text = ();
	my $offset = $delta->retrieve_context($line, $new, $context, \@text);
	for (my $i = 0; $i <= $#text; $i++) {
	    $text[$i] = HTML::Entities::encode($text[$i]);
	    if ($i == $offset) {
		$text[$i] = "<font color=\"red\">" . $text[$i] . "</font>";
	    }
	}

	$vars->{'context'} = $query->pre(join "\n", @text) . $query->p;
    }

    # Display the comments which have been made for this line number
    # in chronological order.
    my @display_comments = ();
    for (my $i = 0; $i <= $#comments; $i++) {
	if ($comments[$i]{fileline} == $line &&
	    $comments[$i]{filenumber} == $fn &&
	    $comments[$i]{filenew} == $new) {
	    my $display_comment = {};
	    my $author = $comments[$i]{author};
	    $display_comment->{author} = Codestriker->filter_email($author);
	    $display_comment->{date} = $comments[$i]{date};
	    $display_comment->{data} = $comments[$i]{data};
	    $display_comment->{metrics} = $comments[$i]{metrics};
	    $display_comment->{line} = "";
	    $display_comment->{lineurl} = "";
	    $display_comment->{linename} = "";
	    $display_comment->{line} = "";
	    $display_comment->{lineurl} = "";
	    $display_comment->{linename} = "";
	    push @display_comments, $display_comment;
	}
    }
    $vars->{'comments'} = \@display_comments;

    # Store the metrics associated with this comment, if any.  Store the
    # metrics configuration, in addition to the current values set for this
    # comment state, if any.
    my @metrics = ();
    my $current_metrics_for_comment;
    if ($#display_comments > -1) {
	$current_metrics_for_comment = $display_comments[0]->{metrics};
    }
    foreach my $metric_config (@{ $Codestriker::comment_state_metrics }) {
	my $metric_data = {};
	$metric_data->{name} = $metric_config->{name};
	$metric_data->{values} = $metric_config->{values};
	$metric_data->{default_value} = $metric_config->{default_value};
	$metric_data->{current_value} =
	    $current_metrics_for_comment->{$metric_config->{name}};
	push @metrics, $metric_data;
    }
    $vars->{'metrics'} = \@metrics;

    # Populate the form values.
    $vars->{'line'} = $line;
    $vars->{'topic'} = $topicid;
    $vars->{'mode'} = $mode;
    $vars->{'anchor'} = $anchor;
    $vars->{'email'} = $email;
    $vars->{'fn'} = $fn;
    $vars->{'new'} = $new;

    # Add the "other" reviewers, which is all the reviewers without the
    # address set in $email.
    my @reviewers = split ', ', $topic->{reviewers};
    @reviewers = grep !/^$email$/, @reviewers;
    $vars->{'reviewers'} = \@reviewers;

    # Display the output via the template.
    my $template = Codestriker::Http::Template->new("editcomment");
    $template->process($vars);

    $http_response->generate_footer();

    # Fire the topic listener to indicate that the user has viewed the topic.
    Codestriker::TopicListeners::Manager::topic_viewed($email, $topic);
}

1;
