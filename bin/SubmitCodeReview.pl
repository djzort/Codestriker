#!/usr/bin/perl

###############################################################################
# SubmitCodeReview.pl
# A utility for automating the submission of CVS code reviews to Codestriker.
#
# Copyright (c) 2003 Altona Ed, LLC
# Written by Aaron Kardell.
# All rights reserved.
#
# May be redistributed and modified only under the terms of the GPL.
# Absolutely no warranty of any kind, express or implied, is granted.
###############################################################################

$REVIEWER = '';
$BASE_URL = '';
$MODULE_NAME = '';

$do_slow_condense = 0;
$do_http_transfer = 1;
$do_file_output = 0;

$next_is_special = 0;
foreach $arg (@ARGV) {
  if ($next_is_special) {
    if ($next_is_special eq '--file') {
      $do_http_transfer = 0;
      $do_file_output = $arg;
    }
    elsif ($next_is_special eq '--url') {
      $BASE_URL = $arg;
      $do_http_transfer = 1;
      $do_file_output = 0;
    }
    elsif ($next_is_special eq '--reviewer') {
      $REVIEWER = $arg;
    }
    elsif ($next_is_special eq '--module_name') {
      $MODULE_NAME = $arg;
    }
    $next_is_special = 0;
  }
  elsif ($arg eq '--condense') {
    $do_slow_condense = 1;
  }
  elsif ($arg eq '--file') {
    $next_is_special = '--file';
  }
  elsif ($arg eq '--url') {
    $next_is_special = '--url';
  }
  elsif ($arg eq '--reviewer') {
    $next_is_special = '--reviewer';
  }
  elsif ($arg eq '--module-name') {
    $next_is_special = '--module-name';
  }
  elsif ($arg eq '--help' || $arg eq '-h' || $arg eq '-H') {
    &print_help;
  }
}

$addl_diff_switches = '';
if ($do_slow_condense) {
  $addl_diff_switches = ' -d ';
}

if (! -e ($ENV{HOME}."/.crcache")) {
  mkdir($ENV{HOME}."/.crcache");
}

if ($do_http_transfer) {
  $lwp_avail = eval {
    no warnings 'all';
    require LWP::UserAgent;
    require HTTP::Request;
    require HTTP::Request::Common;
    1;
  };

  if (!$lwp_avail) {
    print "LWP::UserAgent not installed, so direct posting not available.\nTry --file instead.\n\n";
    &print_help;
  }

  require LWP::UserAgent;
  require HTTP::Request;
  require HTTP::Request::Common;

  if ($BASE_URL =~ m|^https?://([^/]+)/|) {
    $HOST_PORT = $1;
    if ($HOST_PORT !~ /:/) {
      $HOST_PORT .= ':80';
    }
  }

  if (! -e ($ENV{HOME}."/.cremail")) {
    print "Please enter your e-mail address: ";
    $MY_EMAIL = &getinputnotblank;
    chomp($MY_EMAIL);
    open (SETEMAIL, ">".$ENV{HOME}."/.cremail");
    print SETEMAIL "$MY_EMAIL\n";
    close (SETEMAIL);
    print "Thanks.\n";
  }

  $ua = new LWP::UserAgent;
  $req = HTTP::Request->new(GET => "$BASE_URL");
  $res = $ua->request($req);
  $first_check = 1;
  if ($res->code ne '401' && (!$res->is_success || $res->content eq '')) {
    print "Unable to contact host specified.  Edit this file or specify a different host.\nAlternatively, try --file instead.\n\n";
    &print_help;
  }
  while ($res->code eq '401') {
    if ($first_check) {
      print "A password is required when submitting from offsite.\n";
    }
    else {
      print "Invalid password, please try again.\n";
    }
    ($username, $password) = &get_credentials;
    $ua = new LWP::UserAgent;
    $REALM = $res->header('WWW-Authenticate');
    $REALM =~ s/^[^"]*"//;
    $REALM =~ s/"[^"]*$//;
    $ua->credentials($HOST_PORT, $REALM, $username, $password);
    $req = HTTP::Request->new(GET => "$BASE_URL");
    $res = $ua->request($req);
    $first_check = 0;
  }

  open (GETEMAIL, $ENV{HOME}."/.cremail");
  $MY_EMAIL = <GETEMAIL>;
  chomp($MY_EMAIL);
  close (GETEMAIL);
}

$current_dir = `pwd`;
$current_dir =~ s/[\r\n]//sg;

print "Inspecting files in: $current_dir\n";

open (CVSROOT, "CVS/Root");
$cvsroot = <CVSROOT>;
close (CVSROOT);

$cvsroot =~ s/\015//g;
$cvsroot =~ s/\012//g;
$cvsroot =~ s/^.*:([^:]*)$/$1/g;
$cvsroot =~ s|/$||;

open (CVSREPOSITORY, "CVS/Repository");
$cvsrepository = <CVSREPOSITORY>;
close (CVSREPOSITORY);

$cvsrepository =~ s/\015//g;
$cvsrepository =~ s/\012//g;

$MODULE_NAME =~ s|/$||;

if ($MODULE_NAME) {
  $cvsrepository =~ s|^$MODULE_NAME/?||;
}

$cvsrootandmodule = $cvsroot.'/'.$MODULE_NAME;

$cvs_status_out = `cvs status 2>/dev/null`;
$cvs_status_out =~ s/\015//sg;

@file_infos = split(/^=+$/m,$cvs_status_out);
splice(@file_infos,0,1);

@modified_files = ();

foreach $file_info (@file_infos) {
  $version = 'NV';
  if ($file_info =~ /Working revision:\s+(.*?)$/m) {
    $version = $1;
    if ($version eq 'New file!') {
      $version = 'NF';
    }
  }
  if ($file_info =~ /Status: Needs Merge/m || $file_info =~ /Status: Needs Patch/m || $file_info =~ /Status: Needs Checkout/m) {
    die "You must do a CVS update before submitting a code review.\n";
  }
  elsif ($file_info =~ /Status: Locally Modified/m || $file_info =~ /Status: File had conflicts on merge/m) {
    if ($file_info =~ m|Repository revision:[^/]+(/.*)$|m) {
      $file = $1;
      $file =~ s/,v$//;
      $file =~ s|^$cvsrootandmodule/||;
      if ($file_info =~ /Status: File had conflicts on merge/m) {
        print "WARNING: $file had conflicts on merge, which may or may not have been fixed yet.\n";
      }
      $file =~ s|/Attic/|/|;
      push (@modified_files, $file);
      $file_version{$file} = $version;
    }
  }
  elsif ($file_info =~ /Status: Locally Added/m) {
    if ($file_info =~ m|File: *([^ ]+) |m) {
      $file = $1;
      $file = `find . -name "$file"`;
      foreach $f (split(/\n/,$file)) {
        if ($f) {
          $f =~ s|^\./||;
	  if ($cvsrepository) {
	    $f = $cvsrepository . '/' . $f;
	  }
          push (@modified_files, $f);
          $file_version{$f} = $version;
        }
      }
    }
  }
}

if (@modified_files == 0) {
  die "No files have been changed, so no code review is needed.\n";
}

$all_selection = 0;

while ($all_selection == 0) {
  print "\nThe following files have changed:\n";
  foreach $file (@modified_files) {
    print "  $file\n";
  }
  print "Include Code Review for 1) All; 2) Only files I will select? ";
  $line = &getinput;
  if ($line == 1 || $line == 2) {
    $all_selection = $line;
  }
}

if ($all_selection == 2) {
  $done = 0;
  %include_these = {};
  while (!$done) {
    print "\nInclude the following files with a *:\n";
    $counter = 1;
    foreach $file (@modified_files) {
      print "  $counter) ";
      if ($counter < 10) { print "  "; }
      elsif ($counter < 100) { print " "; }
      if ($include_these{$counter}) { print "* "; }
      else { print "  "; }
      print "$file\n";
      $counter++;
    }
    print "Enter number(s) to toggle, ALL, NONE, or DONE? ";
    $line = &getinput;
    if ($line =~ /done/i) {
      $done = 1;
    }
    elsif ($line =~ /(all|none)/i) {
      $toggle_to = ($line =~ /all/i);
      for ($i=1; $i<=@modified_files; $i++) {
        $include_these{$i} = $toggle_to;
      }
    }
    else {
      @nums = split(/[^\d\-]+/, $line);
      foreach $num (@nums) {
        if ($num =~ /^(\d+)-(\d+)$/) {
          $begin = $1;
          $end = $2;
          if ($end < $begin) { $t = $end; $end = $begin; $begin = $t; }
          for ($num=$begin; $num<=$end; $num++) {
            $include_these{$num} = ($include_these{$num} ? 0 : 1);
          }
        }
        else {
          $include_these{$num} = ($include_these{$num} ? 0 : 1);
        }
      }
    }
  }
  for ($i=@modified_files; $i>=1; $i--) {
    if ($include_these{$i} == 0) {
      splice(@modified_files, $i-1, 1);
    }
  }
}

print "\nThe following will be included in the Code Review:\n";
@incremental_eligible = ();
foreach $file (@modified_files) {
  $file_no_slash = $file;
  $file_no_slash =~ s|/|__|g;
  $file_no_slash = $ENV{HOME}."/.crcache/$file_no_slash--".$file_version{$file};
  if (-e $file_no_slash) {
    push(@incremental_eligible, $file);
    $incremental_locs{$file} = $file_no_slash;
  }
  print "  $file\n";
}

@modified_incremental = ();

if (@incremental_eligible > 0) {
  $done = 0;
  $doinc = '';
  while (!$done) {
    print "\nYou are eligible for an 'incremental' code review. Do incremental? [Y]/N: ";
    $doinc = lc(&getinput);
    if ($doinc eq 'y' || $doinc eq '') {
      $doinc = 1;
      $done = 1;
    }
    elsif ($doinc eq 'n') {
      $doinc = 0;
      $done = 1;
    }
  }

  if ($doinc) {
    @modified_incremental = @incremental_eligible;
    my %tmp_inc;
    foreach $file (@modified_incremental) {
      $tmp_inc{$file} = 1;
    }

    for ($i=@modified_files-1; $i>=0; $i--) {
      if ($tmp_inc{$modified_files[$i]}) {
        splice(@modified_files,$i,1);
      }
    }
  }
}

if ($do_http_transfer) {
  if (!$REVIEWER) {
    print "\nEnter the e-mail address of the reviewer: ";
    $REVIEWER = &getinputnotblank;
  }

  print "\nEnter a title: ";
  $title = &getinputnotblank;

  print "\nEnter a description (End with new-line,Ctrl-D): \n";
  $description = &getmultipleinputnotblank;

  print "\nEnter request IDs addressed if any (separate with commas): ";
  $bug_ids = &getinput;

  $project_id = 0;
  while (!$project_id) {
    %projects_hash = &getprojects;
    @projects = sort keys %projects_hash;
    $counter = 1;
    print "\nPlease choose a Project Category: \n";
    foreach $project (@projects) {
      print "  $counter) ";
      if ($counter < 10) { print " "; }
      print "$project\n";
      $counter++;
    }
    print "  $counter) ";
    if ($counter < 10) { print " "; }
    print "Add A Category\n";
    print "Choose One: ";
    $line = &getinput;
    if ($line <= 0 || @projects+1 < $line) { next; }
    elsif (@projects+1 == $line) {
      print "Enter New Project Category: ";
      $line = &getinput;
      &addproject($line);
    }
    else {
      $project_id = $projects_hash{$projects[$line-1]};
    }
  }
}

if ($cvsrepository) {
  # TODO: Rethink this, it is not robust enough yet for situations where only a portion of a repository is checked out; use appropriate --module-name parameter to get around this
  $nodirs = ($cvsrepository =~ m|/|g);
  $nodirs++;
  for ($i=0; $i<$nodirs; $i++) {
    chdir('..');
  }
}

$diff_res_cvs = '';
if (@modified_files > 0) {
  $files = join(' ',@modified_files);
  $diff_res_cvs = `cvs diff -uNbB$addl_diff_switches --show-c-function --show-function-line="p[ur][boi][lvt]" --ignore-all-space --ignore-blank-lines --ignore-space-change $files`;
}
$diff_res_inc = '';

foreach $file (@modified_incremental) {
  $file_to_diff = $incremental_locs{$file};
  $this_file_diff = `diff -uNbB$addl_diff_switches --show-c-function --show-function-line="p[ur][boi][lvt]" --ignore-all-space --ignore-blank-lines --ignore-space-change $file_to_diff $file`;
  if (length($this_file_diff) > 0) {
    if ($diff_res_inc) {
      $diff_res_inc .= "\n";
    }
    $version = $file_version{$file};
    $diff_res_inc .= <<"STOP";
Index: $file
===================================================================
RCS file: $cvsrootandmodule/$file,v
retrieving revision $version
diff -u -b -B -b$addl_diff_switches -r$version $file
STOP
    $diff_res_inc .= $this_file_diff;
  }
}

$diff_res = '';
if ($diff_res_cvs) {
  $diff_res = $diff_res_cvs;
}
if ($diff_res_inc) {
  if ($diff_res) {
    $diff_res .= "\n";
  }
  $diff_res .= $diff_res_inc;
}

foreach $file ((@modified_files,@modified_incremental)) {
  $file_no_slash = $file;
  $file_no_slash =~ s|/|__|g;
  $file_no_slash = $ENV{HOME}."/.crcache/$file_no_slash--";
  `rm -f $file_no_slash*`;
  $file_no_slash .= $file_version{$file};
  `cp "$file" "$file_no_slash"`;
}

if ($do_http_transfer) {
  $tmp_file = "/tmp/codereview$$";

  open (TEMP,">$tmp_file");
  print TEMP "$diff_res";
  close (TEMP);

  $ua = new LWP::UserAgent;
  if ($username && $password) { $ua->credentials($HOST_PORT, $REALM, $username, $password); }
  $res = $ua->request(HTTP::Request::Common::POST($BASE_URL, Content_Type => 'form-data', Content => [action=>'submit_topic',topic_title=>$title,topic_description=>$description,projectid=>$project_id,bug_ids=>$bug_ids,email=>$MY_EMAIL,reviewers=>$REVIEWER,cc=>'',topic_file=>[$tmp_file]]));

  unlink ($tmp_file);
}
else {
  open (TEMP,">$do_file_output");
  print TEMP "$diff_res";
  close (TEMP);
}

sub getinput {
  my ($line);
  $line = <STDIN>;
  $line =~ s/\015//sg;
  chomp ($line);
  $line =~ s/^\s+//;
  $line =~ s/\s+$//;
  return $line;
}

sub getinputnotblank {
  my ($line) = '';
  while (!$line) {
    $line = &getinput;
  }
  return $line;
}

sub getmultipleinput {
  my (@lines);
  @lines = <STDIN>;
  chomp (@lines);
  my ($retval);
  $retval = join("\n", @lines);
  $retval =~ s/\015//sg;
  return $retval;
}

sub getmultipleinputnotblank {
  my ($line) = '';
  while (!$line) {
    $line = &getmultipleinput;
    $line2 = $line;
    $line2 =~ s/^[\r\n]+//s;
    $line2 =~ s/[\r\n]+$//s;
    $line2 =~ s/^\s+//s;
    $line2 =~ s/\s+$//s;
    $line2 =~ s/^[\r\n]+//s;
    $line2 =~ s/[\r\n]+$//s;
    $line2 =~ s/^\s+//s;
    $line2 =~ s/\s+$//s;
    if (!$line2) { $line = $line2; }
  }
  return $line;
}

sub getprojects {
  my ($ua,$req,$res,$content,%response,@links);
  $ua = new LWP::UserAgent;
  if ($username && $password) { $ua->credentials($HOST_PORT, $REALM, $username, $password); }
  $req = HTTP::Request->new(GET => "$BASE_URL?action=list_projects");
  $res = $ua->request($req);
  $content = $res->content;
  if ($content =~ /<body.*?Project list(.*?)<HR>/si) {
    $content = $1;
    @links = ($content =~ m|(<A.*?>.*?</A>)|sig);
    foreach $content (@links) {
      if ($content =~ m|projectid=(\d+).*?>(.*?)</|) {
        $response{$2} = $1;
      }
    }
  }
  return %response;
}

sub addproject {
  my ($project_name) = @_;
  my ($ua,$req,$res);
  $ua = new LWP::UserAgent;
  if ($username && $password) { $ua->credentials($HOST_PORT, $REALM, $username, $password); }
  $req = POST $BASE_URL, [action=>'submit_project',project_name=>$project_name,project_description=>$project_name];
  $res = $ua->request($req);
}

sub get_credentials {
  print "Username: ";
  my ($username) = &getinputnotblank;
  print "Password (will show up on screen): ";
  my ($password) = &getinputnotblank;
  return ($username, $password);
}

sub print_help {
  print "SubmitCodeReview.pl [--help] [--condense] [--file output-file] [--url url]\n";
  print "  [--reviewer email] [--module-name module]\n";
  print "A utility for automating the submission of CVS code reviews to Codestriker.\n";
  print "  --condense will include -d in the diff command used.\n";
  print "  --reviewer specifies the e-mail address of the reviewer.\n";
  print "  --module-name specifies the module name to strip from directory the path.\n";
  print "  --file specifies to output code review to the specified file.\n";
  print "  --url specifies to send code review to the given codestriker.pl URL.\n";
  print "  If neither --file or --url is specified, the URL hardcoded in\n";
  print "    SubmitCodeReview.pl is used.\n";
  exit 0;
}
