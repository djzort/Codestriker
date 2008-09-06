###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Line filter for converting tabs to the appropriate number of &nbsp;
# entities.

package Codestriker::Http::LxrLineFilter;

use strict;

use Codestriker::Http::LineFilter;

@Codestriker::Http::LxrLineFilter::ISA =
  ("Codestriker::Http::LineFilter");

# TODO: close the database handle correctly.

# Take the LXR configuration as a parameter and create a connection to the LXR database
# for symbol lookup.
sub new {
    my ($type, $lxr_config) = @_;

    my $self = Codestriker::Http::LineFilter->new();

    # Store the LXR-specific configuration.
    $self->{url} = $lxr_config->{url};

    # Create a connection to the LXR database.
    my $password = defined $lxr_config->{password} ?
      $lxr_config->{password} : $lxr_config->{passwd};
    $self->{dbh} = DBI->connect($lxr_config->{db}, $lxr_config->{user},
                                $password,
                                {
                                 AutoCommit=>0, RaiseError=>0, PrintError=>0})
      || die "Couldn't connect to LXR database: " . DBI->errstr;

    # Create the appropriate prepared statement for retrieving LXR symbols.
    # Depending on the LXR deployment, the table name is either "symbols"
    # or "lxr_symbols".  Try to determine this silently.
    $self->{select_ids} =
      $self->{dbh}->prepare_cached('SELECT count(symname) FROM symbols where symname = ?');
    my $success = defined $self->{select_ids};
    $success &&= $self->{select_ids}->execute('test');
    $success &&= $self->{select_ids}->finish;
    if (! $success) {
        $self->{select_ids} =
          $self->{dbh}->prepare_cached('SELECT count(symname) FROM lxr_symbols where symname = ?');
    }

    # Re-enable error reporting again.
    $self->{dbh}->{RaiseError} = 1;
    $self->{dbh}->{PrintError} = 1;

    # Cache for storing which IDs have been found.
    $self->{idhash} = {};

    return bless $self, $type;
}

# Given an identifier, wrap it within the appropriate <a href> tag if it
# is a known identifier to LXR, otherwise just return the id.  To avoid
# excessive crap, only consider those identifiers which are at least 4
# characters long.
sub lxr_ident($$) {
    my ($self, $id) = @_;

    my $count = 0;
    if (length($id) >= 4) {
        # Check if the id has not yet been found in lxr.
        if (! exists $self->{idhash}->{$id}) {
            # Initialise this entry.
            $self->{idhash}->{$id} = 0;

            # Fetch ids from lxr and store the result.
            $self->{select_ids}->execute($id);
            ($count) = $self->{select_ids}->fetchrow_array();
            $self->{idhash}->{$id} = $count;
        } else {
            $count = $self->{idhash}->{$id};
        }
    }

    # Check if the id has been found in lxr.
    if ($count > 0) {
        return '<a href="' . $self->{url} . $id . '" class="fid">' . $id . '</a>';
    } else {
        return $id;
    }
}

# Break up the string into potential identifies, and see if lxr can process
# them.
sub _handle_identifiers {
    my ($self, $text) = @_;

    # Break the string into potential identifiers, and look them up to see
    # if they can be hyperlinked to an LXR lookup.
    my @data_tokens = split /([_A-z]\w+)/, $text;
    my $newdata = "";
    foreach my $token (@data_tokens) {
        if ($token =~ /^[_A-z]/) {
            if ($token eq "nbsp" || $token eq "quot" || $token eq "amp" ||
                $token eq "lt" || $token eq "gt") {
                # TODO: is this still needed?
                # HACK - ignore potential HTML entities.  This needs to be
                # done in a smarter fashion later.
                $newdata .= $token;
            } else {
                $newdata .= $self->lxr_ident($token);
            }
        } else {
            $newdata .= $token;
        }
    }

    return $newdata;
}

# Ensure the prepared statements and database connection to LXR is closed.
sub DESTROY {
    my ($self) = @_;

    $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");

    $self->{select_ids}->finish;
    $self->{dbh}->disconnect;
}


1;
