###############################################################################
# Codestriker: Copyright (c) 2001,2002,2003 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Subversion repository access package.

package Codestriker::Repository::Subversion;
use IPC::Open3;

use strict;
use Fatal qw / open close /;

# Constructor, which takes as a parameter the repository url.
sub new {
    my ($type, $repository_url, $user, $password) = @_;

    # Determine if there are additional parameters required for user
    # authentication.
    my @userCmdLine = ();
    if (defined($user) && defined($password)) {
        push @userCmdLine, '--username';
	push @userCmdLine, $user;
	push @userCmdLine, '--password';
	push @userCmdLine, $password;
    }

    # Sanitise the repository URL.
    $repository_url = sanitise_url_component($repository_url);

    my $self = {};
    $self->{repository_url} = $repository_url;
    $self->{userCmdLine} = \@userCmdLine;
    $self->{repository_string} = $repository_url;
    $self->{repository_string} .= ";$user" if defined $user;
    $self->{repository_string} .= ";$password" if defined $password;
    if ($self->{repository_string} !~ /^svn:/) {
	$self->{repository_string} = "svn:" . $self->{repository_string};
    }

    bless $self, $type;
}

# Sanitise a Subversion URL component, by replacing spaces with %20 and @
# symbols with %40, so that there is no confused with pegged revisions.  Also
# remove any leading and trailing slashes.
sub sanitise_url_component {
    my $url = shift;
    $url =~ s/\/$//;
    $url =~ s/^\///;
    $url =~ s/ /%20/g;
    $url =~ s/\@/%40/g;
    return $url;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Sanitise the filename.
    $filename = sanitise_url_component($filename);

    my $read_data = '';
    my $read_stdout_fh = new FileHandle;
    open($read_stdout_fh, '>', \$read_data);
    my @args = ();
    push @args, 'cat';
    push @args, '--non-interactive';
    push @args, '--no-auth-cache';
    push @args, @{ $self->{userCmdLine} };
    push @args, $self->{repository_url} . '/' . $filename . '@' . $revision;
    Codestriker::execute_command($read_stdout_fh, undef,
				 $Codestriker::svn, @args);

    # Process the data for the topic.
    open($read_stdout_fh, '<', \$read_data);
    for (my $i = 1; <$read_stdout_fh>; $i++) {
	$_ = Codestriker::decode_topic_text($_);
	chop;
	$$content_array_ref[$i] = $_;
    }
    
    return $Codestriker::OK;
}

# Retrieve the "root" of this repository.
sub getRoot ($) {
    my ($self) = @_;
    return $self->{repository_url};
}

# Return a URL which views the specified file and revision.
sub getViewUrl ($$$) {
    my ($self, $filename, $revision) = @_;

    # Lookup the file viewer from the configuration.
    my $viewer = $Codestriker::file_viewer->{$self->toString()};
    if (! (defined $viewer)) {
	$viewer = $Codestriker::file_viewer->{$self->{repository_string}};
    }

    return (defined $viewer) ? $viewer . "/" . $filename : "";
}

# Return a string representation of this repository.
sub toString ($) {
    my ($self) = @_;
    return $self->{repository_string};
}

# Given a Subversion URL, determine if it refers to a directory or a file.
sub is_file_url {
    my ($self, $url) = @_;
    my $file_url;

    eval {
	my @args = ();
	push @args, 'info';
	push @args, '--non-interactive';
	push @args, '--no-auth-cache';
	push @args, @{ $self->{userCmdLine} };
	push @args, '--xml';
	push @args, $self->{repository_url} . '/' . $url;
	my $read_data;
	my $read_stdout_fh = new FileHandle;
	open($read_stdout_fh, '>', \$read_data);

	Codestriker::execute_command($read_stdout_fh, undef,
				     $Codestriker::svn, @args);
	open($read_stdout_fh, '<', \$read_data);
	while (<$read_stdout_fh>) {
	    if (/kind\s*\=\s*\"(\w+)\"/) {
		$file_url = $1 =~ /^File$/io;
		last;
	    }
	}
    };
    if ($@ || !(defined $file_url)) {
	# The above command failed, try using the older method which only works
	# in an English locale.  This supports Subversion 1.2 or earlier
	# releases, which don't support the --xml flag for the info command.
	my @args = ();
	push @args, 'cat';
	push @args, '--non-interactive';
	push @args, '--no-auth-cache';
	push @args, @{ $self->{userCmdLine} };
	push @args, '--revision';
	push @args, 'HEAD';
	push @args, $self->{repository_url} . '/' . $url;

	my $read_stdout_data;
	my $read_stdout_fh = new FileHandle;
	open($read_stdout_fh, '>', \$read_stdout_data);

	my $read_stderr_data;
	my $read_stderr_fh = new FileHandle;
	open($read_stderr_fh, '>', \$read_stderr_data);

	Codestriker::execute_command($read_stdout_fh, $read_stderr_fh,
				     $Codestriker::svn, @args);
	$file_url = 1;
	open($read_stderr_fh, '<', \$read_stderr_data);
	while(<$read_stderr_fh>) {
	    if (/^svn:.* refers to a directory/) {
		$file_url = 0;
		last;
	    }
	}
    }
    
    return $file_url;
}

# The getDiff operation, pull out a change set based on the start and end 
# revision number, confined to the specified moduled_name.
sub getDiff {
    my ($self, $start_tag, $end_tag, $module_name, $stdout_fh, $stderr_fh) = @_;

    # Sanitise the URL, and determine if it refers to a directory or filename.
    $module_name = sanitise_url_component($module_name);
    my $directory;
    if ($self->is_file_url($module_name)) {
	$module_name =~ /(.*)\/[^\/]+/;
	$directory = $1;
    } else {
	$directory = $module_name;
    }

    # Execute the diff command.
    my $read_stdout_data = '';
    my $read_stdout_fh = new FileHandle;
    open($read_stdout_fh, '>', \$read_stdout_data);

    my @args = ();

    my $revision;
    if ($start_tag eq "" && $end_tag ne "") {
	$revision = $end_tag;
    } elsif ($start_tag ne "" && $end_tag eq "") {
	$revision = $start_tag;
    }

    if (defined $revision) {
	# Just pull out the actual contents of the file.
	push @args, 'cat';
	push @args, '--non-interactive';
	push @args, '--no-auth-cache';
	push @args, @{ $self->{userCmdLine} };
	push @args, '-r';
	push @args, $revision;
	push @args, $self->{repository_url} . '/' . $module_name;
	Codestriker::execute_command($read_stdout_fh, $stderr_fh,
				     $Codestriker::svn, @args);

	open($read_stdout_fh, '<', \$read_stdout_data);
	my $number_lines = 0;
	while(<$read_stdout_fh>) {
	    $number_lines++;
	}
	Codestriker::execute_command($read_stdout_fh, $stderr_fh,
				     $Codestriker::svn, @args);

	open($read_stdout_fh, '<', \$read_stdout_data);


	# Fake the diff header.
	print $stdout_fh "Index: $module_name\n";
	print $stdout_fh "===================================================================\n";
	print $stdout_fh "--- /dev/null\n";
	print $stdout_fh "+++ $module_name\t(revision $revision)\n";
	print $stdout_fh "@@ -0,0 +1,$number_lines @@\n";
	while(<$read_stdout_fh>) {
	    print $stdout_fh "+ $_";
	}
    } else {
	push @args, 'diff';
	push @args, '--non-interactive';
	push @args, '--no-auth-cache';
	push @args, @{ $self->{userCmdLine} };
	push @args, '-r';
	push @args, $start_tag . ':' . $end_tag;
	push @args, '--old';
	push @args, $self->{repository_url};
	push @args, $module_name;
	Codestriker::execute_command($read_stdout_fh, $stderr_fh,
				     $Codestriker::svn, @args);
	
	open($read_stdout_fh, '<', \$read_stdout_data);
	while(<$read_stdout_fh>) {
	    my $line = $_;
	
	    # If the user specifies a path (a branch in Subversion), the
	    # diff file does not come back with a path rooted from the
	    # repository base making it impossible to pull the entire file
	    # back out. This code attempts to change the diff file on the
	    # fly to ensure that the full path is present. This is a bug
	    # against Subversion, so eventually it will be fixed, so this
	    # code can't break when the diff command starts returning the
	    # full path.
	    if ($line =~ /^--- / || $line =~ /^\+\+\+ / ||
		$line =~ /^Index: /) {
		# Check if the bug has been fixed.
		if ($line =~ /^\+\+\+ $module_name/ == 0 && 
		    $line =~ /^--- $module_name/ == 0 &&
		    $line =~ /^Index: $module_name/ == 0) {
		    $line =~ s/^--- /--- $directory\// or
			$line =~ s/^Index: /Index: $directory\// or
			$line =~ s/^\+\+\+ /\+\+\+ $directory\//;
		}
	    }

	    print $stdout_fh $line;
	}
    }

    return $Codestriker::OK;
}

1;
