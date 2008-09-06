###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Factory class for retrieving a repository object.

package Codestriker::Repository::RepositoryFactory;

use strict;

use Codestriker::Repository::Cvs;
use Codestriker::Repository::ViewCvs;
use Codestriker::Repository::CvsWeb;
use Codestriker::Repository::Subversion;
use Codestriker::Repository::Perforce;
use Codestriker::Repository::Vss;
use Codestriker::Repository::ClearCaseSnapshot;
use Codestriker::Repository::ClearCaseDynamic;

# Factory method for retrieving a Repository object, given a descriptor.
sub get ($$) {
    my ($type, $repository) = @_;

    if (!(defined $repository) || $repository eq "") {
        return undef;
    }

    if ($repository =~ /^\s*(\/.*?)\/*\s*$/) {
        # CVS repository on the local machine.
        return Codestriker::Repository::Cvs->build_local($1, '');

    } elsif ($repository =~ /^\s*:local:([A-z]:[\\\/].*?)\\*\s*$/) {
        # Windoze "local" CVS repository.
        return Codestriker::Repository::Cvs->build_local($1, ':local:');

    } elsif ($repository =~ /^\s*([A-z]:[\\\/].*?)\\*\s*$/) {
        # Windoze CVS repository.
        return Codestriker::Repository::Cvs->build_local($1, '');

    } elsif ($repository =~ /^\s*:pserver(.*):(.*):(.*)@(.*):(.*)\s*$/i) {
        # Pserver repository.
        return Codestriker::Repository::Cvs->build_pserver($1, $2, $3, $4, $5);

    } elsif ($repository =~ /^\s*:ext(.*):(.*)@(.*):(.*)\s*$/i) {
        # Pserver repository.
        return Codestriker::Repository::Cvs->build_ext($1, $2, $3, $4);

    } elsif ($repository =~ /^\s*:sspi:(.*):(.*)@(.*):([A-z]:[\\\/].*?)\\*\s*(.*)\s*$/i) {
        # NT SSPI CVS repository.  Example:
        # :sspi:MYNTDOMAIN\jdoe:password@mycvsserver:c:\repository_on_server
        # :sspi:<host address>:\ANDCVS
        return Codestriker::Repository::Cvs->build_sspi($1, $2, $3, $4);

    } elsif ($repository =~ /^\s*(https?:\/\/.*viewcvs\.cgi)\/*\s+(.*?)\/*\s*$/i) {
        # View CVS repository.
        return Codestriker::Repository::ViewCvs->new($1, $2);

    } elsif ($repository =~ /^\s*(https?:\/\/.*cvsweb\.cgi)\/*\s+(.*?)\/*\s*$/i) {
        # CVS web repository.
        return Codestriker::Repository::CvsWeb->new($1, $2);
    } elsif ($repository =~ /^\s*(svn:\/\/.*)\s*;(.*);(.*)$/i) {
        # Subversion repository using svnserver with username and password.
        return Codestriker::Repository::Subversion->new($1, $2, $3);
    } elsif ($repository =~ /^\s*(svn:\/\/.*)\s*$/i) {
        return Codestriker::Repository::Subversion->new($1);
    } elsif ($repository =~ /^\s*svn:(.*)\s*;(.*);(.*)$/i) {
        # Subversion repository with username and password
        return Codestriker::Repository::Subversion->new($1, $2, $3);

    } elsif ($repository =~ /^\s*svn:(.*)\s*$/i) {
        # Subversion repository.
        return Codestriker::Repository::Subversion->new($1);

    } elsif ($repository =~ /^\s*perforce:(.*):(.*)@(.*):(.*)\s*$/i) {
        # Perforce repository.
        return Codestriker::Repository::Perforce->new($1, $2, $3, $4);

    } elsif ($repository =~ /^\s*perforce:(.*)@(.*):(.*)\s*$/i) {
        # Perforce repository with no password.
        return Codestriker::Repository::Perforce->new($1, '', $2, $3);

    } elsif ($repository =~ /^\s*vss:(.*);(.*);(.*)$/i) {
        # Visual Source Safe repository spec with SSDIR, user and password.
        return Codestriker::Repository::Vss->new($2,$3,$1);

    } elsif ($repository =~ /^\s*vss:(.*);(.*)$/i) {
        # Visual Source Safe repository spec with user and password.
        return Codestriker::Repository::Vss->new($1,$2);

    } elsif ($repository =~ /^\s*vss:(.*):(.*)$/i) {
        # Older-style Visual Source Safe (VSS) repository spec.
        return Codestriker::Repository::Vss->new($1,$2);
    } elsif ($repository =~ /^\s*clearcase:dyn:(.*)$/i) {
        # ClearCase Dynamic repository.
        return Codestriker::Repository::ClearCaseDynamic->new($1);
    } elsif ($repository =~ /^\s*clearcase:(.*)$/i) {
        # ClearCase Snapshot repository.
        return Codestriker::Repository::ClearCaseSnapshot->new($1);

    } else {
        # Unknown repository type.
        print STDERR "Codestriker: Couldn't match repository: \"$repository\"\n";
        return undef;
    }
}

1;
