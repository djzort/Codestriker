###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Collection of routines for processing the HTTP input.

package Codestriker::Http::Input;

use strict;
use Encode qw(decode_utf8);

use CGI::Carp 'fatalsToBrowser';

use Codestriker::Http::Cookie;

sub _set_property_from_cookie( $$$ );
sub _untaint( $$$ );
sub _untaint_name( $$ );
sub _untaint_digits( $$ );
sub _untaint_filename( $$ );
sub _untaint_revision( $$ );
sub _untaint_email( $$ );
sub _untaint_emails( $$ );
sub _untaint_bug_ids( $$ );
sub _untaint_alphanumeric( $$ );

# Default valiue to set the context if it is not set.
my $DEFAULT_CONTEXT = 2;

# Constructor for this class.
sub new($$$) {
    my ($type, $query, $http_response) = @_;
    my $self = {};
    $self->{query} = $query;
    $self->{http_response} = $http_response;
    return bless $self, $type;
}

sub extract_cgi_parameters {
    my ($self) = @_;

    # Retrieve all of the known Codestriker CGI parameters, and check they
    # are valid.
    my $query = $self->{query};
    $self->{action} = $query->param('action');
    $self->{button} = $query->param('button');
    $self->{topic} = $query->param('topic');
    $self->{line} = $query->param('line');
    $self->{fn} = $query->param('fn');
    $self->{context} = $query->param('context');
    $self->{action} = $query->param('action');
    $self->{comments} = decode_utf8($query->param('comments'));
    $self->{email} = $query->param('email');
    $self->{author} = $query->param('author');
    $self->{topic_text} = decode_utf8($query->param('topic_text'));
    $self->{topic_title} = decode_utf8($query->param('topic_title'));
    $self->{topic_description} = decode_utf8($query->param('topic_description'));
    $self->{reviewers} = $query->param('reviewers');
    $self->{cc} = $query->param('cc');
    $self->{comment_cc} = $query->param('comment_cc');
    $self->{topic_state} = decode_utf8($query->param('topic_state'));
    $self->{comment_state} = decode_utf8($query->param('comment_state'));
    $self->{revision} = $query->param('revision');
    $self->{filename} = decode_utf8($query->param('filename'));
    $self->{linenumber} = $query->param('linenumber');
    $self->{mode} = $query->param('mode');
    $self->{fview} = $query->param('fview');
    $self->{bug_ids} = $query->param('bug_ids');
    $self->{new} = $query->param('new');
    $self->{tabwidth} = $query->param('tabwidth');
    $self->{sauthor} = $query->param('sauthor');
    $self->{sreviewer} = $query->param('sreviewer');
    $self->{scc} = $query->param('scc');
    $self->{sbugid} = $query->param('sbugid');
    $self->{stext} = decode_utf8($query->param('stext'));
    $self->{stitle} = decode_utf8($query->param('stitle'));
    $self->{sdescription} = decode_utf8($query->param('sdescription'));
    $self->{scomments} = decode_utf8($query->param('scomments'));
    $self->{sbody} = decode_utf8($query->param('sbody'));
    $self->{sfilename} = decode_utf8($query->param('sfilename'));
    $self->{sstate} = decode_utf8($query->param('sstate'));
    $self->{sproject} = decode_utf8($query->param('sproject'));
    $self->{scontext} = $query->param('scontext');
    $self->{version} = $query->param('version');
    $self->{redirect} = $query->param('redirect');
    $self->{a} = $query->param('a');
    $self->{updated} = decode_utf8($query->param('updated'));
    $self->{repository} = decode_utf8($query->param('repository'));
    $self->{parallel} = $query->param('parallel');
    $self->{projectid} = $query->param('projectid');
    $self->{project_name} = decode_utf8($query->param('project_name'));
    $self->{project_description} = decode_utf8($query->param('project_description'));
    $self->{project_state} = decode_utf8($query->param('project_state'));
    $self->{start_tag} = decode_utf8($query->param('start_tag'));
    $self->{end_tag} = decode_utf8($query->param('end_tag'));
    $self->{module} = decode_utf8($query->param('module'));
    $self->{topic_sort_change} = $query->param('topic_sort_change');
    $self->{format} = $query->param('format');
    $self->{obsoletes} = $query->param('obsoletes');
    my @selected_topics = $query->param('selected_topics');
    $self->{selected_topics} = \@selected_topics;
    my @selected_comments = $query->param('selected_comments');
    $self->{selected_comments} = \@selected_comments;
    $self->{default_to_head} = $query->param('default_to_head');
    $self->{email_event} = $query->param('email_event');
    $self->{redirect} = $query->param('redirect');
    $self->{challenge} = $query->param('challenge');
    $self->{password} = $query->param('password');
    $self->{feedback} = $query->param('feedback');

    # Set any missing parameters from the cookie.
    my %cookie = Codestriker::Http::Cookie->get($query);

    # Set things to the empty string rather than undefined.
    $self->{cc} = "" if ! defined $self->{cc};
    $self->{reviewers} = "" if ! defined $self->{reviewers};
    $self->{bug_ids} = "" if ! defined $self->{bug_ids};
    $self->{sstate} = "" if ! defined $self->{sstate};
    $self->{sproject} = "" if ! defined $self->{sproject};
    $self->{sauthor} = "" if ! defined $self->{sauthor};
    $self->{a} = "" if ! defined $self->{a};
    $self->{updated} = 0 if ! defined $self->{updated};
    $self->{repository} = "" if ! defined $self->{repository};
    $self->{project_name} = "" if ! defined $self->{project_name};
    $self->{project_description} = "" if ! defined $self->{project_description};
    $self->{project_state} = "" if ! defined $self->{project_state};
    $self->{topic_sort_change} = "" if ! defined $self->{topic_sort_change};
    $self->{format} = "html" if ! defined $self->{format};
    $self->{obsoletes} = "" if ! defined $self->{obsoletes};
    $self->{default_to_head} = 0 if ! defined $self->{default_to_head};
    $self->{email_event} = 1 if ! defined $self->{email_event};
    $self->{feedback} = "" if ! defined $self->{feedback};

    my @topic_metrics = $query->param('topic_metric');
    $self->{topic_metric} = \@topic_metrics;

    my @author_metrics = $query->param('author_metric');
    $self->{author_metric} = \@author_metrics;

    for (my $userindex = 0; $userindex < 100; ++$userindex) {
        my @reviewer_metrics = $query->param("reviewer_metric,$userindex");

        last if (scalar(@reviewer_metrics) == 0);
        $self->{"reviewer_metric,$userindex"} = \@reviewer_metrics;
    }

    # Set the comment state metric data.
    foreach my $comment_state_metric (@{$Codestriker::comment_state_metrics}) {
        my $name = "comment_state_metric_" . $comment_state_metric->{name};
        $self->{$name} = $query->param($name);
    }

    # Remove those annoying \r's in textareas.
    if (defined $self->{topic_description}) {
        $self->{topic_description} =~ s/\r//g;
    } else {
        $self->{topic_description} = "";
    }

    if (defined $self->{comments}) {
        $self->{comments} =~ s/\r//g;
    } else {
        $self->{comments} = "";
    }

    # Record the file handler for a topic text upload, if any.  Also record the
    # mime type of the file if it has been set, default to text/plain
    # otherwise.
    # Note topic_file is forced to be a string to get the filename (and
    # not have any confusion with the file object).  CGI.pm weirdness.
    if (defined $query->param('topic_file')) {
        $self->{fh_filename} = "" . $query->param('topic_file');
    } else {
        $self->{fh_filename} = undef;
    }
    $self->{fh} = $query->upload('topic_file');
    $self->{fh_mime_type} = 'text/plain';

    # This code doesn't work, it produces a warning like:
    #
    # Use of uninitialized value in hash element at (eval 34) line 3.
    #
    # Since mime-types aren't used yet, this code is skipped for now.
    #
    #    if ((defined $self->{fh_filename})) {
    #    (defined $query->uploadInfo($query->param('topic_file'))) {
    #    $self->{fh_mime_type} =
    #        $query->uploadInfo($self->{fh_filename})->{'Content-Type'};
    #    }

    # Set parameter values from the cookie if they are not set.
    $self->_set_property_from_cookie('context', $DEFAULT_CONTEXT);
    $self->_set_property_from_cookie('mode',
                                     $Codestriker::default_topic_create_mode);
    $self->_set_property_from_cookie('tabwidth',
                                     $Codestriker::default_tabwidth);
    $self->_set_property_from_cookie('fview',
                                     $Codestriker::default_file_to_view);
    $self->_set_property_from_cookie('email', "");
    $self->_set_property_from_cookie('repository', "");
    $self->_set_property_from_cookie('projectid', 0);
    $self->_set_property_from_cookie('module', "");
    $self->_set_property_from_cookie('topicsort', "");

    $self->_untaint('topic_sort_change', '(title)|(author)|(created)|(state)');

    # Untaint the required input.
    $self->_untaint_name('action');
    $self->_untaint_digits('topic');
    $self->_untaint_digits('projectid');
    $self->_untaint_email('email');
    $self->_untaint_email('author');
    $self->_untaint_emails('reviewers');
    $self->_untaint_emails('cc');
    $self->_untaint_filename('filename');
    $self->_untaint_revision('revision');
    $self->_untaint_bug_ids('bug_ids');
    $self->_untaint_digits('new');
    $self->_untaint_digits('tabwidth');
    $self->_untaint_filename('start_tag');
    $self->_untaint_filename('end_tag');

    # VSS module names can be things like $/TestProject/Project-name, so
    # this needs to be handled in a special way.
    $self->_untaint('module', '\$?[-_\/\w\.\s]+');

    $self->_untaint_digits('scontext');
    $self->_untaint_comma_digits('sstate');
    $self->_untaint_comma_digits('sproject');
    $self->_untaint_comma_digits('obsoletes');

    # Canonicalise the bug_ids and email list parameters if required.
    $self->{reviewers} = $self->make_canonical_email_list($self->{reviewers});
    $self->{cc} = $self->make_canonical_email_list($self->{cc});
    $self->{bug_ids} = $self->make_canonical_bug_list($self->{bug_ids});
    $self->{comment_cc} = $self->make_canonical_email_list($self->{comment_cc});
}

# Return the query object associated with this object.
sub get_query($) {
    my ($self) = @_;

    return $self->{query};
}

# Return the specified parameter.
sub get($$) {
    my ($self, $param) = @_;

    return $self->{$param};
}

# Given a list of email addresses separated by commas and spaces, return
# a canonical form, where they are separated by a comma and a space.
sub make_canonical_email_list($$) {
    my ($type, $emails) = @_;

    if (defined $emails && $emails ne "") {
        # Chew off white space that is around the emails addresses.
        $emails =~ s/^[\s]*//;
        $emails =~ s/[\s]*$//;

        return join ', ', split /[\s,;]+/, $emails;
    } else {
        return $emails;
    }
}

# Given a list of bug ids separated by commas and spaces, return
# a canonical form, where they are separated by a comma and a space.
sub make_canonical_bug_list($$) {
    my ($type, $bugs) = @_;

    if (defined $bugs && $bugs ne "") {
        return join ', ', split /[\s,;]+/, $bugs;
    } else {
        return "";
    }
}

# Set the specified property from the cookie if it is not set.  If the cookie
# is not set, use the supplied default value.
sub _set_property_from_cookie($$$) {
    my ($self, $name, $default) = @_;

    my %cookie = Codestriker::Http::Cookie->get($self->{query});
    if (! defined $self->{$name} || $self->{$name} eq "") {
        $self->{$name} = exists $cookie{$name} && $cookie{$name} ne "" ? $cookie{$name} : $default;
    }
}

# Untaint the specified property, against the expected regular expression.
# Remove leading and trailing whitespace.
sub _untaint($$$) {
    my ($self, $name, $regexp) = @_;

    my $value = $self->{$name};
    if (defined $value && $value ne "") {
        if ($value =~ /^\s*(${regexp})\s*$/) {
            # Untaint the value.
            $self->{$name} = $1;
        } else {
            my $error_message = "Input parameter $name has invalid value: " .
              HTML::Entities::encode($value);
            $self->{http_response}->error($error_message);
        }
    } else {
        $self->{$name} = "";
    }
}

# Untaint a parameter which should be a bunch of alphabetical characters and
# underscores.
sub _untaint_name($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '[A-Za-z_]+');
}

# Untaint a parameter which should be a bunch of digits.
sub _untaint_digits($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '\d+');
}

# Untaint a parameter which should be a valid filename.
sub _untaint_filename($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '[-_\/\@\w\.\s]+');
}

# Untaint a parameter that should be a revision number.
sub _untaint_revision($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '[\d\.]+');
}

# Untaint a parameter that should be a comma separated list of digits.
sub _untaint_comma_digits($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '[\d\,]+');
}

# Untaint a single email address, which should be a regular email address.
sub _untaint_email($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '[\s]*[-_\+\w\.]{1,200}(\@[-_\+\w\.]{1,200})?[\s]*');
}

# Untaint a list of email addresses.
sub _untaint_emails($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '[\s]*([-_\+\w\.]{1,200}(\@[-_\+\w\.]{1,200})?[\s,;]*){1,100}[\s]*');
}

# Untaint a list of bug ids.
sub _untaint_bug_ids($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '([0-9]+[\s,;]*){1,100}');
}

1;
