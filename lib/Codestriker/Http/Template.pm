###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Package for the creation and management of templates.

package Codestriker::Http::Template;

use strict;
use Template;

use Codestriker;

# Create a new template.
sub new($$) {
    my ($type, $name) = @_;

    my $self = {};
    $self->{name} = $name;
    $self->{template} =
	Template->new({
	    # Location of templates.
	    INCLUDE_PATH => 
		$Codestriker::BASEDIR . "/template/en/custom:" .
		$Codestriker::BASEDIR . "/template/en/default" ,

	    # Remove white-space before template directives
	    # (PRE_CHOMP) and at the beginning and end of templates
	    # and template blocks (TRIM) for better looking, more
	    # compact content.  Use the plus sign at the beginning #
	    # of directives to maintain white space (i.e. [%+
	    # DIRECTIVE %]).
	    PRE_CHOMP => 1,
	    TRIM => 1, 
	    
	    # Where to compile the templates.
	    COMPILE_DIR => $Codestriker::BASEDIR . 'cgi-bin/data/',

	    # Codestriker-specific plugins.
	    PLUGIN_BASE => 'Codestriker::Template::Plugin'
	    })
	|| die Template->error();

    return bless $self, $type;
}

# Return the template associated with this object.
sub get_template($) {
    my ($self) = @_;

    return $self->{template};
}

# Process the template.  Note the results are stored into a variable, which is
# then output to STDOUT.  This is required, as if the HTTP response is a 
# compressed stream (which is tied to STDOUT), for some reason, this doesn't
# play well with TT's default STDOUT writing.  Storing it to a temporary
# variable does the trick.
sub process($$) {
    my ($self, $vars) = @_;

    # Add into the vars the standard .conf file options. 	

    # Indicate if the "delete" button should be visible or not.
    $vars->{'delete_enabled'} = $Codestriker::allow_delete;

    # Indicate if the "list/search" functionality is available or not.
    $vars->{'searchlist_enabled'} = $Codestriker::allow_searchlist;

    # Indicate if the "project" functionality is available or not.
    $vars->{'projects_enabled'} = Codestriker->projects_disabled() ? 0 : 1;

    # Indicate if bug db integration is enabled.
    $vars->{'bugdb_enabled'} = ($Codestriker::bug_db ne "") ? 1 : 0;

    # Indicate if antispam_email is enabled.
    $vars->{'antispam_email'} = $Codestriker::antispam_email;

    # CodeStriker Version, used in the title.
    $vars->{'version'} = $Codestriker::VERSION;

    $vars->{'main_title'} = $Codestriker::title;

    $vars->{'rss_enabled'} = $Codestriker::rss_enabled;

    # Indicate if the repository field should be displayed.
    $vars->{'allow_repositories'} = scalar(@Codestriker::valid_repositories) ? 1 : 0;

    # Display the topic size limit if any.
    $vars->{'maximum_topic_size_lines'} = $Codestriker::maximum_topic_size_lines eq "" ? 
                                          0 : 
                                          $Codestriker::maximum_topic_size_lines;
                                          
    $vars->{'suggested_topic_size_lines'} = $Codestriker::suggested_topic_size_lines eq "" ? 
                                          0 : 
                                          $Codestriker::suggested_topic_size_lines;


    my $query = new CGI;
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);

    # Handle the links and parameters in the main title bar.
    $vars->{'list_url'} =
	$url_builder->list_topics_url("", "", "", "", "", "", "",
				      "", "", "", [ 0 ], undef);
    $vars->{'create_topic_url'} = $url_builder->create_topic_url();
    $vars->{'search_url'} = $url_builder->search_url();
    $vars->{'doc_url'} = $url_builder->doc_url();

    my $data = "";
    my $rc = $self->{template}->process($self->{name} . ".html.tmpl",
					$vars, \$data);
    die $self->{template}->error() if (!defined $rc || $rc == 0);
    print $data;
    return $rc;
}

1;
    
