###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for listing topics.

package Codestriker::Http::Method::ListTopicsMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::ListTopicsMethod::ISA =
  ("Codestriker::Http::Method");

sub new {
    my ($type, $query) = @_;

    my $self = Codestriker::Http::Method->new($query, 'list_topics.*');
    return bless $self, $type;
}

# Generate a URL for this method.
sub url {
    my ($self, %args) = @_;

    my $sstate = defined $args{sstate} ? CGI::escape(join ',', @{$args{sstate}}) : "";
    my $sproject = defined $args{sproject} ? CGI::escape(join ',', @{$args{sproject}}) : "";
    $args{action} = 'list_topics_rss' if defined $args{rss} && $args{rss};
    $args{action} = 'list_topics' if ! defined $args{action};

    return $self->{url_prefix} . "?action=" . $args{action} .
      (defined $args{sauthor} && $args{sauthor} ne "" ? "&sauthor=" . CGI::escape($args{sauthor}) : "") .
        (defined $args{sreviewer} && $args{sreviewer} ne "" ? "&sreviewer=" . CGI::escape($args{sreviewer}) : "") .
          (defined $args{scc} && $args{scc} ne "" ? "&scc=" . CGI::escape($args{scc}) : "") .
            (defined $args{sbugid} && $args{sbugid} ne "" ? "&sbugid=" . CGI::escape($args{sbugid}) : "") .
              (defined $args{stext} && $args{stext} ne "" ? "&stext=" . CGI::escape($args{stext}) : "") .
                (defined $args{stitle} && $args{stitle} ne "" ? "&stitle=" . CGI::escape($args{stitle}) : "") .
                  (defined $args{sdescription} && $args{sdescription} ne "" ? "&sdescription=" . CGI::escape($args{sdescription}) : "") .
                    (defined $args{scomments} && $args{scomments} ne "" ? "&scomments=" . CGI::escape($args{scomments}) : "") .
                      (defined $args{sbody} && $args{sbody} ne "" ? "&sbody=" . CGI::escape($args{sbody}) : "") .
                        (defined $args{sfilename} && $args{sfilename} ne "" ? "&sfilename=" . CGI::escape($args{sfilename}) : "") .
                          (defined $args{content} && $args{content} ne "" ? "&content=" . CGI::escape($args{content}) : "") .
                            ($sstate ne "" ? "&sstate=$sstate" : "") .
                              ($sproject ne "" ? "&sproject=$sproject" : "");
}

sub execute {
    my ($self, $http_input, $http_output) = @_;

    my $action = $http_input->{query}->param('action');
    if ($action eq "list_topics_rss") {
        Codestriker::Action::ListTopicsRSS->process($http_input, $http_output);
    } else {
        Codestriker::Action::ListTopics->process($http_input, $http_output);
    }

}

1;
