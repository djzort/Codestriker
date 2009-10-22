###############################################################################
# Codestriker: Copyright (c) 2004 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.
#
# Handler for ClearCase Dynamic Views.
# Contributed by "Avinandan Sengupta" <avinna_seng at users.sourceforge.net>.
# 
# 22nd July 2009
# Added support to directly fetch info (diff) from clearcase.
# Now, no need to manually take diff from clearcase and upload.
# Just provide versions in 'start-tag' & 'end-tag' and file in 'module'.
# Contributed by "Lakshmivaragan" <lakshmivaragan at users.sourceforge.net>.

package Codestriker::Repository::ClearCaseDynamic;

use strict;
use File::Spec;

use Codestriker::Repository;
@Codestriker::Repository::ClearCaseDynamic::ISA = ("Codestriker::Repository");

# Put this in an eval block so that this becomes an optional dependency for
# those people who don't use this module.
eval("use ClearCase::CtCmd");

# Constructor.
# viewname:vobs_dir - absolute path to the vobs dir
#                     (mount point on unix/drive letter on windows)
# This dynamic view should be mounted on the same host on which Codestriker
# is running.
sub new ($$)
  {
      my ($type, $url) = @_;

      my $self = Codestriker::Repository->new("clearcase:dyn:$url");
      $url =~ /([^:]*):(.*)/;
      $self->{dynamic_view_name} = $1;
      $self->{vobs_dir} = $2;

      bless $self, $type;
  }

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$)
  {
      my ($self, $filename, $revision, $content_array_ref) = @_;
      my $clearcase;

      # Check if we are running under Windows, which doesn't support
      # the setview and endview commands.
      if (! Codestriker::is_windows()) {
          # Set the current view to the repository's dynamic view name.
          $clearcase = ClearCase::CtCmd->new();
          (my $status, my $stdout, my $error_msg) =
            $clearcase->exec('setview', $self->{dynamic_view_name});

          # Check the result of the setview command.
          if ($status) {
              croak("Failed to open view: " . $self->{dynamic_view_name} .
                    ": $error_msg\n");
          }
      }

      # Execute the remaining code in an eval block to ensure the endview
      # command is always called.
      eval {
          # Construct the filename in the view, based on its path and
          # revision.
          my $full_element_name = File::Spec->catfile($self->{vobs_dir},
                                                      $filename);
          if (defined($revision) && length($revision) > 0) {
              $full_element_name = $full_element_name . '@@' . $revision;
          }

          # Load the file directly into the given array.
          open (CONTENTFILE, "$full_element_name")
            || die "Couldn't open file: $full_element_name: $!";
          for (my $i = 1; <CONTENTFILE>; $i++) {
              chop;
              $$content_array_ref[$i] = $_;
          }
          close CONTENTFILE;
      };
      if ($@) {
          # Something went wrong in the above code, record the error message
          # and continue to ensure the view is closed.
          croak("Failed to retrieve ${filename}:${revision}: $@\n");
      }

      # Close the view.
      if (! Codestriker::is_windows()) {
          (my $status, my $stdout, my $error_msg) =
            $clearcase->exec('endview', $self->{dynamic_view_name});
          if ($status) {
              croak("Failed to close view: " . $self->{dynamic_view_name} .
                    ": $error_msg\n");
          }
      }
  }

# Retrieve the "root" of this repository.
sub getRoot ($) {
    my ($self) = @_;
    return $self->{vobs_dir};
}

# Given a start tag, end tag and a module name, store the text into
# the specified file handle.  If the size of the diff goes beyond the
# limit, then return the appropriate error code.
sub getDiff ($$$$$$) {
    my ($self, $start_tag, $end_tag, $module_name, $fh, $stderr_fh) = @_;

    # Flag variables to determine the exec type
    my $compare_previous = 0;

    if ($start_tag eq '' && $end_tag eq '')
    {
        # Both tags cannot be empty.
        print $stderr_fh "Both start tag and end tag cannot be empty.\n";
        return $Codestriker::OK;
    }

    # If only a single tag is defined, make end_tag hold the value.
    if ($start_tag ne '' && $end_tag eq '')
    {
        $end_tag = $start_tag;
        $start_tag = '';
    }

    # If Start tag is empty, but has valid end tag, take diff with previous version.
    if ($start_tag eq '' && $end_tag ne '')
    {
        $compare_previous = 1;
    }

    if ($self->{dynamic_view_name} eq '')
    {
        # View tag is empty.
        print $stderr_fh "View tag is empty. Check 'codestriker.conf' for configuration of clearcase.\n";
        return $Codestriker::OK;
    }

    if ($self->{vobs_dir} eq '')
    {
        # VOBS URL is empty.
        print $stderr_fh "VOBS URL is empty. Check 'codestriker.conf' for configuration of clearcase.\n";
        return $Codestriker::OK;
    }

    my $ctcmd = "";

    $ctcmd = "setview " . $self->{dynamic_view_name};
    (my $status, my $output, my $errormsg) = ClearCase::CtCmd::exec($ctcmd);

    # $status is set to 1 if ctcmd exec succeeded. Otherwise 0.
    if ($status)
    {
        print $stderr_fh "CtCmd::exec($ctcmd) failed: $errormsg.\n";
        return $Codestriker::OK;
    }

    # Check if element exists and if exists, find if it is file / dir.
    my $filename = $self->{vobs_dir} . '/' . $module_name;
    $ctcmd = "ls -l -dir " . $filename;
    ($status, $output, $errormsg) = ClearCase::CtCmd::exec($ctcmd);

    # CtCmd status for "ls -l -dir" is set to 0 if success; 1 on failure. CtCmd bug???
    if ($status)
    {
        print $stderr_fh "CtCmd Exec($ctcmd) failed: $errormsg.\n";
        return $Codestriker::OK;
    }
    elsif ($output =~ /^directory version/)
    {
        # The element is a directory.
        print $stderr_fh "At present CC::Dynamic does not support adding all files of a dir if directory is given.\n";
        return $Codestriker::OK;
    }
    elsif ($output =~ /^version/)
    {
        # The element is a file.
    }

    # Next, get the diff between two versions provided.
    my $secondver = $filename . "@@" . $end_tag;
    if ($compare_previous == 1)
    {
        $ctcmd = "diff -serial_format -pred $secondver";
    }
    else
    {
        my $firstver = $filename . "@@" . $start_tag;
        $ctcmd = "diff -serial_format $firstver $secondver";
    }
    ($status, $output, $errormsg) = ClearCase::CtCmd::exec($ctcmd);

    # CtCmd status for "diff" is set to 0 if success; 1 on failure. CtCmd bug???
    if (!$status)
    {
        print $stderr_fh "CtCmd Exec($ctcmd) failed: $errormsg.\n";
        return $Codestriker::OK;
    }
    else
    {
        # Write the diff output to FileHandler.
        print $fh $output;
    }
    return $Codestriker::OK;
}

1;
