###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Factory class for retrieving a repository object.

package Codestriker::Repository::RepositoryFactory;

use strict;

use Codestriker::Repository::CvsLocal;
use Codestriker::Repository::ViewCvs;
use Codestriker::Repository::CvsWeb;

# Factory method for retrieving a Repository object, given a descriptor.
sub get ($$) {
    my ($type, $repository) = @_;

    if (!(defined $repository) || $repository eq "") {
	return undef;
    }

    if ($repository =~ /^\s*(\/.*?)\/*\s*$/) {
	# CVS repository on the local machine.
	return Codestriker::Repository::CvsLocal->new($1);
    } elsif ($repository =~ /^\s*(https?:\/\/.*viewcvs\.cgi)\/*\s+(.*?)\/*\s*$/i) {
	# View CVS repository.
	return Codestriker::Repository::ViewCvs->new($1, $2);
    } elsif ($repository =~ /^\s*(https?:\/\/.*cvsweb\.cgi)\/*\s+(.*?)\/*\s*$/i) {
	# CVS web repository.
	return Codestriker::Repository::CvsWeb->new($1, $2);
    } else {
	# Unknown repository type.
	print STDERR "Codestriker: Couldn't match repository: \"$repository\"\n";
	return undef;
    }
}

1;

    

