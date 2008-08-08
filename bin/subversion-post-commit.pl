#!/usr/bin/perl -w

# Post commit script for automatically creating a Codestriker
# topic from a Subversion commit.  Some of this code was inspired/stolen
# from the Subversion commit-email.pl script.

use strict;
use Carp;

##############################################################################
#
# Start of site-specific configuration.
#
# Make sure the project and repository parameters match your Codestriker
# configuration.
#
##############################################################################

# Codestriker-specific imports.  Set this to your Codestriker installation.
use lib '/var/www/codestriker/bin';
use CodestrikerClient;

# Codestriker specific parameters for topic creation.
my $CODESTRIKER_URL = 'http://localhost.localdomain/codestriker/codestriker.pl';
my $CODESTRIKER_PROJECT = 'Subversion Commit Project Name';
my $CODESTRIKER_REPOSITORY = 'svn://hostname/var/svn/repos/product/trunk';
my $CODESTRIKER_REVIEWERS = 'engineering@company.com';
my $CODESTRIKER_CC = '';

# Email domain to append to subversion username which is used to construct
# the author's email address.
my $email_domain = 'company.com';

# Svnlook path.
my $svnlook = "/usr/bin/svnlook";

##############################################################################
#
# End of site-specific configuration.
#
##############################################################################

# First argument is the repository followed by the revision number.
my $repository = pop @ARGV;
my $revision = pop @ARGV;

# Get the author, date, and log from svnlook.
my @svnlooklines = &read_from_process($svnlook, 'info', $repository, '-r', $revision);
my $author = shift @svnlooklines;
my $date = shift @svnlooklines;
shift @svnlooklines;
my @log = map { "$_\n" } @svnlooklines;

# Get the diff lines from svnlook.
my @difflines = &read_from_process($svnlook, 'diff', $repository, '-r', $revision);

# Now create the Codestriker topic.  The topic title will be the
# first line of the log message prefixed with "Commit: ".
# The topic description is the entire log message.
my $topic_title = "Commit: " . $log[0];
my $topic_description = join("\n", @log);
my $bug_ids = $topic_description;

# Truncate the title if necessary.
if (length($topic_title) > 77) {
    $topic_title = substr($topic_title, 0, 77) . "...";
}

# Check for any matching Bug id text.
my @bugs = ();
$bug_ids =~ s/.*[Bb][Uu][Gg]:?(\d+)\b.*/$1 /g;
while ($bug_ids =~ /\b[Bb][Uu][Gg]:?\s*(\d+)\b/g) {
    push @bugs, $1;
}

my $client = CodestrikerClient->new($CODESTRIKER_URL);
$client->create_topic({
	topic_title => $topic_title,
	topic_description => $topic_description,
	project_name => $CODESTRIKER_PROJECT,
	repository => $CODESTRIKER_REPOSITORY,
	bug_ids => join(", ", @bugs),
	email => $author . '@' . $email_domain,
	reviewers => $CODESTRIKER_REVIEWERS,
	cc => $CODESTRIKER_CC,
	topic_text => join("\n", @difflines)
	});

# Start a child process safely without using /bin/sh.
sub safe_read_from_pipe
{
    unless (@_)
    {
	croak "$0: safe_read_from_pipe passed no arguments.\n";
    }
    
    my $pid = open(SAFE_READ, '-|');
    unless (defined $pid)
    {
	die "$0: cannot fork: $!\n";
    }
    unless ($pid)
    {
	open(STDERR, ">&STDOUT")
	    or die "$0: cannot dup STDOUT: $!\n";
	exec(@_)
	    or die "$0: cannot exec `@_': $!\n";
    }
    my @output;
    while (<SAFE_READ>)
    {
	s/[\r\n]+$//;
	push(@output, $_);
    }
    close(SAFE_READ);
    my $result = $?;
    my $exit   = $result >> 8;
    my $signal = $result & 127;
    my $cd     = $result & 128 ? "with core dump" : "";
    if ($signal or $cd)
    {
	warn "$0: pipe from `@_' failed $cd: exit=$exit signal=$signal\n";
    }
    if (wantarray)
    {
	return ($result, @output);
    }
    else
    {
	return $result;
    }
}

# Use safe_read_from_pipe to start a child process safely and return
# the output if it succeeded or an error message followed by the output
# if it failed.
sub read_from_process
{
    unless (@_)
    {
	croak "$0: read_from_process passed no arguments.\n";
    }
    my ($status, @output) = &safe_read_from_pipe(@_);
    if ($status)
    {
	return ("$0: `@_' failed with this output:", @output);
    }
    else
    {
	return @output;
    }
}
