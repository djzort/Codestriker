#!/usr/bin/perl
#
# Perl filter to handle the log messages from the checkin of files in
# a directory.  This script will group the lists of files by log
# message, and mail a single consolidated log message at the end of
# the commit.
#
# This file assumes a pre-commit checking program that leaves the
# names of the first and last commit directories in a temporary file.
#
# Contributed by David Hampton <hampton@cisco.com>
# Roy Fielding removed useless code and added log/mail of new files
# Ken Coar added special processing (i.e., no diffs) for binary files
# Jon Stevens added a few new features and cleaned up some of the 
# output
#
# David Sitsky modified this slightly so that it also creates a new
# codestriker topic automatically.

############################################################
#
# Setup instructions
#
############################################################
#
# Create a directory $CVSROOT/commitlogs and allow
# the cvs process to write to it.
#
# Edit the options below.
#
############################################################
#
# Configurable options
#
############################################################
#
# Where do you want the RCS ID and delta info?
# 0 = none,
# 1 = in mail only,
# 2 = rcsids in both mail and logs.
#
$rcsidinfo = 2;

############################################################
#
# Constants
#
############################################################
$STATE_NONE    = 0;
$STATE_CHANGED = 1;
$STATE_ADDED   = 2;
$STATE_REMOVED = 3;
$STATE_LOG     = 4;

$TMPDIR        = $ENV{'TMPDIR'} || '/tmp';
$FILE_PREFIX   = '#cvs.';

$LAST_FILE     = "$TMPDIR/${FILE_PREFIX}lastdir";
$CHANGED_FILE  = "$TMPDIR/${FILE_PREFIX}files.changed";
$ADDED_FILE    = "$TMPDIR/${FILE_PREFIX}files.added";
$REMOVED_FILE  = "$TMPDIR/${FILE_PREFIX}files.removed";
$LOG_FILE      = "$TMPDIR/${FILE_PREFIX}files.log";
$BRANCH_FILE   = "$TMPDIR/${FILE_PREFIX}files.branch";
$SUMMARY_FILE  = "$TMPDIR/${FILE_PREFIX}files.summary";

$CVSROOT       = $ENV{'CVSROOT'};

$CVSBIN        = '/usr/bin';
$PATH          = "$PATH:/bin:/usr/bin";
$MAIL_CMD      = "| /usr/lib/sendmail -i -t";
$MAIL_TO       = 'engineering@localhost.localdomain';
$MAIL_FROM     = "$ENV{'USER'}\@localhost.localdomain";
$SUBJECT_PRE   = 'CVS update:';

# Codestriker-specific imports.
use lib '/var/www/codestriker-1.8.4/lib';
use Codestriker::Http::CreateTopic;

# Codestriker specific parameters for topic creation.
$CODESTRIKER_URL = 'http://localhost/codestriker/codestriker.pl';
$CODESTRIKER_PROJECT = 'Project CVS';
$CODESTRIKER_REPOSITORY = '/var/lib/cvs';
$CODESTRIKER_REVIEWERS = 'engineering@localhost.localdomain';
$CODESTRIKER_CC = '';

############################################################
#
# Subroutines
#
############################################################

sub format_names {
    local($dir, @files) = @_;
    local(@lines);

    $lines[0] = sprintf(" %-08s", $dir);
    foreach $file (@files) {
        if (length($lines[$#lines]) + length($file) > 60) {
            $lines[++$#lines] = sprintf(" %8s", " ");
        }
        $lines[$#lines] .= " ".$file;
    }
    @lines;
}

sub cleanup_tmpfiles {
    local(@files);

    opendir(DIR, $TMPDIR);
    push(@files, grep(/^${FILE_PREFIX}.*\.${id}$/, readdir(DIR)));
    closedir(DIR);
    foreach (@files) {
        unlink "$TMPDIR/$_";
    }
}

sub write_logfile {
    local($filename, @lines) = @_;

    open(FILE, ">$filename") || die ("Cannot open log file $filename: $!\n");
    print(FILE join("\n", @lines), "\n");
    close(FILE);
}

sub append_to_file {
    local($filename, $dir, @files) = @_;

    if (@files) {
        local(@lines) = &format_names($dir, @files);
        open(FILE, ">>$filename") || die ("Cannot open file $filename: $!\n");
        print(FILE join("\n", @lines), "\n");
        close(FILE);
    }
}

sub write_line {
    local($filename, $line) = @_;

    open(FILE, ">$filename") || die("Cannot open file $filename: $!\n");
    print(FILE $line, "\n");
    close(FILE);
}

sub append_line {
    local($filename, $line) = @_;

    open(FILE, ">>$filename") || die("Cannot open file $filename: $!\n");
    print(FILE $line, "\n");
    close(FILE);
}

sub read_line {
    local($filename) = @_;
    local($line);

    open(FILE, "<$filename") || die("Cannot open file $filename: $!\n");
    $line = <FILE>;
    close(FILE);
    chomp($line);
    $line;
}

sub read_file {
    local($filename, $leader) = @_;
    local(@text) = ();

    open(FILE, "<$filename") || return ();
    while (<FILE>) {
        chomp;
        push(@text, sprintf("  %-10s  %s", $leader, $_));
        $leader = "";
    }
    close(FILE);
    @text;
}

sub read_logfile {
    local($filename, $leader) = @_;
    local(@text) = ();

    open(FILE, "<$filename") || die ("Cannot open log file $filename: $!\n");
    while (<FILE>) {
        chomp;
        push(@text, $leader.$_);
    }
    close(FILE);
    @text;
}

#
# do an 'cvs -Qn status' on each file in the arguments, and extract info.
#
sub change_summary {
    local($out, @filenames) = @_;
    local(@revline);
    local($file, $rev, $rcsfile, $line);

    while (@filenames) {
        $file = shift @filenames;

        if ("$file" eq "") {
            next;
        }

        open(RCS, "-|") || exec "$CVSBIN/cvs", '-Qn', 'status', $file;

        $rev = "";
        $delta = "";
        $rcsfile = "";


        while (<RCS>) {
            if (/^[ \t]*Repository revision/) {
                chomp;
                @revline = split(' ', $_);
                $rev = $revline[2];
                $rcsfile = $revline[3];
                $rcsfile =~ s,^$CVSROOT/,,;
                $rcsfile =~ s/,v$//;
            }
        }
        close(RCS);


        if ($rev ne '' && $rcsfile ne '') {
            open(RCS, "-|") || exec "$CVSBIN/cvs", '-Qn', 'log', "-r$rev", $file;
            while (<RCS>) {
                if (/^date:/) {
                    chomp;
                    $delta = $_;
                    $delta =~ s/^.*;//;
                    $delta =~ s/^[\s]+lines://;
                }
            }
            close(RCS);
        }

        $diff = "\n\n";

	#
	# Get the differences between this and the previous revision,
	# being aware that new files always have revision '1.1' and
	# new branches always end in '.n.1'.
	#
	if ($rev =~ /^(.*)\.([0-9]+)$/) {
	    $prev = $2 - 1;
	    $prev_rev = $1 . '.' .  $prev;
	    
	    $prev_rev =~ s/\.[0-9]+\.0$//;# Truncate if first rev on branch
		
            open(DIFF, "-|")
		|| exec "$CVSBIN/cvs", '-Qn', 'diff', '-uN',
	                "-r$prev_rev", "-r$rev", $file;

	    while (<DIFF>) {
		$diff .= $_;
	    }
	    close(DIFF);
	    $diff .= "\n\n";
	}

        &append_line($out, $diff);
    }
}


sub build_header {
    local($header);
    delete $ENV{'TZ'};
    local($sec,$min,$hour,$mday,$mon,$year) = localtime(time);

    $header = sprintf("  User: %-8s\n  Date: %02d/%02d/%02d %02d:%02d:%02d",
                       $cvs_user, $year%100, $mon+1, $mday,
                       $hour, $min, $sec);
}

# !!! Mailing-list and history file mappings here !!!
sub mlist_map
{
    local($path) = @_;
   
    if ($path =~ /^([^\/]+)/) { return $1; }
    else                      { return 'apache'; }
}    

sub do_changes_file
{
    local($category, @text) = @_;
    local($changes);

    $changes = "$CVSROOT/CVSROOT/commitlogs/$category";
    if (open(CHANGES, ">>$changes")) {
        print(CHANGES join("\n", @text), "\n\n");
        close(CHANGES);
    }
    else { 
        warn "Cannot open $changes: $!\n";
    }
}

sub mail_notification
{
    local(@text) = @_;

#    print "Mailing the commit message...\n";

    open(MAIL, $MAIL_CMD);
    print MAIL "From: $MAIL_FROM\n";
    print MAIL "To: $MAIL_TO\n";
    print MAIL "Subject: $SUBJECT_PRE $ARGV[0]\n\n";
    print(MAIL join("\n", @text));
    close(MAIL);
}

# Create a Codestriker topic.  The topic title will be the
# first line of the log message prefixed with "CVS commit: ".
# The topic description is the entire log message.
# Return the URL of the created topic if successful, otherwise
# undef.
sub codestriker_create_topic
{
    local($user, $log_ref, $diff_ref) = @_;
    local(@log) = @{$log_ref};
    local(@diff) = @{$diff_ref};

    my $topic_title = "CVS commit: " .$log[0];
    my $topic_description = join("\n", @log);
    my $bug_ids = $topic_description;

    # Check for any matching Bug id text.
    my @bugs = ();
    $bug_ids =~ s/.*[Bb][Uu][Gg]:?(\d+)\b.*/$1 /g;
    while ($bug_ids =~ /\b[Bb][Uu][Gg]:?\s*(\d+)\b/g) {
	push @bugs, $1;
    }

    return Codestriker::Http::CreateTopic->doit({
	url => $CODESTRIKER_URL,
	topic_title => $topic_title,
	topic_description => $topic_description,
	project_name => $CODESTRIKER_PROJECT,
	repository => $CODESTRIKER_REPOSITORY,
	bug_ids => join(", ", @bugs),
	email => $user,
	reviewers => $CODESTRIKER_REVIEWERS,
	cc => $CODESTRIKER_CC,
	topic_text => join("\n", @diff)
	});
}

## process the command line arguments sent to this script
## it returns an array of files, %s, sent from the loginfo
## command
sub process_argv
{
    local(@argv) = @_;
    local(@files);
    local($arg);
#    print "Processing log script arguments...\n";

    while (@argv) {
        $arg = shift @argv;

        if ($arg eq '-u') {
                $cvs_user = shift @argv;
        } else {
                ($donefiles) && die "Too many arguments!\n";
                $donefiles = 1;
                $ARGV[0] = $arg;
                @files = split(' ', $arg);
        }
    }
    return @files;
}

#############################################################
#
# Main Body
#
############################################################
#
# Setup environment
#
umask (002);

#
# Initialize basic variables
#
$id = getpgrp();
$state = $STATE_NONE;
$cvs_user = $ENV{'USER'} || getlogin || (getpwuid($<))[0] || sprintf("uid#%d",$<);
@files = process_argv(@ARGV);
@path = split('/', $files[0]);
$repository = $path[0];
if ($#path == 0) {
    $dir = ".";
} else {
    $dir = join('/', @path[1..$#path]);
}
#print("ARGV  - ", join(":", @ARGV), "\n");
#print("files - ", join(":", @files), "\n");
#print("path  - ", join(":", @path), "\n");
#print("dir   - ", $dir, "\n");
#print("id    - ", $id, "\n");

#
# Map the repository directory to a name for commitlogs.
#
$mlist = &mlist_map($files[0]);

##########################
# Uncomment the following if we ever have per-repository cvs mail

# if (defined($mlist)) {
#     $MAIL_TO = $mlist . '-cvs';
# }
# else { undef $MAIL_TO; }

##########################
#
# Check for a new directory first.  This will always appear as a
# single item in the argument list, and an empty log message.
#
if ($ARGV[0] =~ /New directory/) {
    $header = &build_header;
    @text = ();
    push(@text, $header);
    push(@text, "");
    push(@text, "  ".$ARGV[0]);
    &do_changes_file($mlist, @text);
    &mail_notification(@text) if defined($MAIL_TO);
    exit 0;
}

#
# Iterate over the body of the message collecting information.
#
while (<STDIN>) {
    chomp;                      # Drop the newline

    if (/^Revision\/Branch:/) {
        s,^Revision/Branch:,,;
        push (@branch_lines, split);
        next;
    }
#    next if (/^[ \t]+Tag:/ && $state != $STATE_LOG);
    if (/^Modified Files/) { $state = $STATE_CHANGED; next; }
    if (/^Added Files/)    { $state = $STATE_ADDED;   next; }
    if (/^Removed Files/)  { $state = $STATE_REMOVED; next; }
    if (/^Log Message/)    { $state = $STATE_LOG;     next; }
    s/[ \t\n]+$//;              # delete trailing space
    
    push (@changed_files, split) if ($state == $STATE_CHANGED);
    push (@added_files,   split) if ($state == $STATE_ADDED);
    push (@removed_files, split) if ($state == $STATE_REMOVED);
    if ($state == $STATE_LOG) {
        if (/^PR:$/i ||
            /^Reviewed by:$/i ||
            /^Submitted by:$/i ||
            /^Obtained from:$/i) {
            next;
        }
        push (@log_lines,     $_);
    }
}

#
# Strip leading and trailing blank lines from the log message.  Also
# compress multiple blank lines in the body of the message down to a
# single blank line.
# (Note, this only does the mail and changes log, not the rcs log).
#
while ($#log_lines > -1) {
    last if ($log_lines[0] ne "");
    shift(@log_lines);
}
while ($#log_lines > -1) {
    last if ($log_lines[$#log_lines] ne "");
    pop(@log_lines);
}
for ($i = $#log_lines; $i > 0; $i--) {
    if (($log_lines[$i - 1] eq "") && ($log_lines[$i] eq "")) {
        splice(@log_lines, $i, 1);
    }
}

#
# Find the log file that matches this log message
#
for ($i = 0; ; $i++) {
    last if (! -e "$LOG_FILE.$i.$id");
    @text = &read_logfile("$LOG_FILE.$i.$id", "");
    last if ($#text == -1);
    last if (join(" ", @log_lines) eq join(" ", @text));
}

#
# Spit out the information gathered in this pass.
#
&write_logfile("$LOG_FILE.$i.$id", @log_lines);
&append_to_file("$BRANCH_FILE.$i.$id",  $dir, @branch_lines);
&append_to_file("$ADDED_FILE.$i.$id",   $dir, @added_files);
&append_to_file("$CHANGED_FILE.$i.$id", $dir, @changed_files);
&append_to_file("$REMOVED_FILE.$i.$id", $dir, @removed_files);
if ($rcsidinfo) {
    &change_summary("$SUMMARY_FILE.$i.$id", (@changed_files, @added_files));
}

#
# Check whether this is the last directory.  If not, quit.
#
if (-e "$LAST_FILE.$id") {
   $_ = &read_line("$LAST_FILE.$id");
   $tmpfiles = $files[0];
   $tmpfiles =~ s,([^a-zA-Z0-9_/]),\\$1,g;
   if (! grep(/$tmpfiles$/, $_)) {
        print "More commits to come...\n";
        exit 0
   }
}

#
# This is it.  The commits are all finished.  Lump everything together
# into a single message, fire a copy off to the mailing list, and drop
# it on the end of the Changes file.
#
$header = &build_header;

#
# Produce the final compilation of the log messages
#
@text = ();
@diff_text = ();
push(@text, $header);
push(@text, "");
for ($i = 0; ; $i++) {
    last if (! -e "$LOG_FILE.$i.$id");
    push(@text, &read_file("$BRANCH_FILE.$i.$id", "Branch:"));
    push(@text, &read_file("$CHANGED_FILE.$i.$id", "Modified:"));
    push(@text, &read_file("$ADDED_FILE.$i.$id", "Added:"));
    push(@text, &read_file("$REMOVED_FILE.$i.$id", "Removed:"));
    push(@text, "  Log:");
    push(@text, &read_logfile("$LOG_FILE.$i.$id", "  "));
    if ($rcsidinfo == 2) {
        if (-e "$SUMMARY_FILE.$i.$id") {
            push(@text, "  ");
            push(@diff_text, &read_logfile("$SUMMARY_FILE.$i.$id", ""));
            push(@text, &read_logfile("$SUMMARY_FILE.$i.$id", "  "));
        }
    }
    push(@text, "");
}


#
# Append the log message to the commitlogs/<module> file
#
&do_changes_file($mlist, @text);
#
# Now generate the extra info for the mail message..
#
if ($rcsidinfo == 1) {
    $revhdr = 0;
    for ($i = 0; ; $i++) {
        last if (! -e "$SUMMARY_FILE.$i.$id");
        if (-e "$SUMMARY_FILE.$i.$id") {
            if (!$revhdr++) {
                push(@text, "Revision  Changes    Path");
            }
            push(@text, &read_logfile("$SUMMARY_FILE.$i.$id", ""));
            push(@diff_text, &read_logfile("$SUMMARY_FILE.$i.$id", ""));
        }
    }
    if ($revhdr) {
        push(@text, "");        # consistancy...
    }
}

#
# Now create the Codestriker topic.
#
my $topic_url = &codestriker_create_topic($cvs_user, \@log_lines, \@diff_text);

#
# Mail out the notification.  Prepend the topic url if it is defined.
#
if (defined($MAIL_TO)) {
    if (defined($topic_url)) {
	unshift @text, "";
	unshift @text, "  $topic_url";
	unshift @text, "  Created Codestriker topic at:";
    }
    &mail_notification(@text) if defined($MAIL_TO);
}

&cleanup_tmpfiles;
exit 0;
