###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Module for dispatching a URL to the appropriate Action class.

package Codestriker::Http::Dispatcher;

use strict;
use CGI;

use Codestriker::Http::Method;
use Codestriker::Http::Method::ListTopicsMethod;
use Codestriker::Http::Method::CreateTopicMethod;
use Codestriker::Http::Method::ViewTopicTextMethod;
use Codestriker::Http::Method::ViewTopicCommentsMethod;
use Codestriker::Http::Method::ViewTopicFileMethod;
use Codestriker::Http::Method::ViewTopicMetricsMethod;
use Codestriker::Http::Method::ViewTopicPropertiesMethod;
use Codestriker::Http::Method::DownloadTopicTextMethod;
use Codestriker::Http::Method::UpdateTopicPropertiesMethod;
use Codestriker::Http::Method::UpdateTopicMetricsMethod;
use Codestriker::Http::Method::UpdateCommentMetricsMethod;
use Codestriker::Http::Method::AddCommentMethod;
use Codestriker::Http::Method::CreateCommentMethod;
use Codestriker::Http::Method::AddTopicMethod;
use Codestriker::Http::Method::CreateProjectMethod;
use Codestriker::Http::Method::DownloadMetricsMethod;
use Codestriker::Http::Method::EditProjectMethod;
use Codestriker::Http::Method::UpdateProjectMethod;
use Codestriker::Http::Method::ListProjectsMethod;
use Codestriker::Http::Method::SearchTopicsMethod;
use Codestriker::Http::Method::SubmitSearchTopicsMethod;
use Codestriker::Http::Method::StaticResourcesMethod;
use Codestriker::Http::Method::ViewMetricsMethod;
use Codestriker::Http::Method::UpdateTopicStateMethod;
use Codestriker::Http::Method::AddProjectMethod;
use Codestriker::Http::Method::LoginMethod;
use Codestriker::Http::Method::LogoutMethod;
use Codestriker::Http::Method::AuthenticateMethod;
use Codestriker::Http::Method::NewPasswordMethod;
use Codestriker::Http::Method::UpdatePasswordMethod;
use Codestriker::Http::Method::ResetPasswordMethod;
use Codestriker::Http::Method::CreateNewUserMethod;
use Codestriker::Http::Method::AddNewUserMethod;

# Initialise all of the methods that are known to the system.
sub new {
    my ($type, $query) = @_;

    my $self = {};
    $self->{query} = $query;
    $self->{list_topics_method} =
      Codestriker::Http::Method::ListTopicsMethod->new($query);
    $self->{create_topic_method} =
      Codestriker::Http::Method::CreateTopicMethod->new($query);

    my @methods = ();
    push @methods, Codestriker::Http::Method::SearchTopicsMethod->new($query);
    push @methods, Codestriker::Http::Method::ViewTopicTextMethod->new($query);
    push @methods, Codestriker::Http::Method::ViewTopicCommentsMethod->new($query);
    push @methods, Codestriker::Http::Method::ViewTopicFileMethod->new($query);
    push @methods, Codestriker::Http::Method::ViewTopicMetricsMethod->new($query);
    push @methods, Codestriker::Http::Method::ViewTopicPropertiesMethod->new($query);
    push @methods, Codestriker::Http::Method::UpdateTopicPropertiesMethod->new($query);
    push @methods, Codestriker::Http::Method::UpdateTopicMetricsMethod->new($query);
    push @methods, Codestriker::Http::Method::UpdateCommentMetricsMethod->new($query);
    push @methods, $self->{list_topics_method};
    push @methods, Codestriker::Http::Method::CreateCommentMethod->new($query);
    push @methods, Codestriker::Http::Method::AddCommentMethod->new($query);
    push @methods, Codestriker::Http::Method::AddTopicMethod->new($query);
    push @methods, Codestriker::Http::Method::CreateProjectMethod->new($query);
    push @methods, $self->{create_topic_method};
    push @methods, Codestriker::Http::Method::DownloadTopicTextMethod->new($query);
    push @methods, Codestriker::Http::Method::DownloadMetricsMethod->new($query);
    push @methods, Codestriker::Http::Method::EditProjectMethod->new($query);
    push @methods, Codestriker::Http::Method::UpdateProjectMethod->new($query);
    push @methods, Codestriker::Http::Method::ListProjectsMethod->new($query);
    push @methods, Codestriker::Http::Method::SubmitSearchTopicsMethod->new($query);
    push @methods, Codestriker::Http::Method::StaticResourcesMethod->new($query);
    push @methods, Codestriker::Http::Method::ViewMetricsMethod->new($query);
    push @methods, Codestriker::Http::Method::UpdateTopicStateMethod->new($query);
    push @methods, Codestriker::Http::Method::AddProjectMethod->new($query);
    push @methods, Codestriker::Http::Method::LoginMethod->new($query);
    push @methods, Codestriker::Http::Method::LogoutMethod->new($query);
    push @methods, Codestriker::Http::Method::AuthenticateMethod->new($query);
    push @methods, Codestriker::Http::Method::NewPasswordMethod->new($query);
    push @methods, Codestriker::Http::Method::UpdatePasswordMethod->new($query);
    push @methods, Codestriker::Http::Method::ResetPasswordMethod->new($query);
    push @methods, Codestriker::Http::Method::AddNewUserMethod->new($query);
    push @methods, Codestriker::Http::Method::CreateNewUserMethod->new($query);

    $self->{methods} = \@methods;
    return bless $self, $type;
}

# Determine which method can satisfy the input request and dispatch it
# to the appropriate action.
sub dispatch {
    my ($self, $http_input, $http_output) = @_;

    # Extract all cookie and CGI parameters.
    $http_input->extract_cgi_parameters();

    # Determine which method can handle this URL.
    my $found_method;
    foreach my $method ( @{$self->{methods}} ) {
        if ($method->can_handle($http_input)) {
            $found_method = $method;
            last;
        }
    }

    # Set to a default method if none were found.
    if (! defined $found_method) {
        $found_method = $Codestriker::allow_searchlist ?
          $self->{list_topics_method} : $self->{create_topics_method};
    }

    # Check if the method requires authentication.
    my $user;
    if ($found_method->requires_authentication()) {
        my $query = $http_output->get_query();
        my $email = $http_input->get('email');
        my $password_hash = $http_input->get('password_hash');

        # If the user is not logged in, redirect to the login screen.
        my $full_url = $query->url(-path_info => 1, -query => 1);
        my $login_url =
          Codestriker::Http::Method::LoginMethod->new($query)->url(redirect => $full_url);
        if (!defined($email) || $email eq '' ||
            !defined($password_hash) || $password_hash eq '') {
            print $query->redirect(-URI => $login_url);
            return;
        }

        # If email has been specified, but it doesn't exist, redirect
        # to the login screen.
        if (!Codestriker::Model::User->exists($email)) {
            print $query->redirect(-URI => $login_url);
            return;
        }

        # Check that the user has supplied the right credentials.
        $user = Codestriker::Model::User->new($email);
        if ($user->{password_hash} ne $password_hash) {
            print $query->redirect(-URI => $login_url);
            return;
        }
    }

    # Check if the method requires admin priviledges.
    if (defined $Codestriker::admin_users &&
        $found_method->requires_admin() && !$user->{admin}) {
        $http_output->error("This function requires admin access.");
        return;
    }

    # All checks have completed, execute the method.
    $found_method->execute($http_input, $http_output);
}

1;
