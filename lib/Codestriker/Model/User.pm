###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling user data.

package Codestriker::Model::User;

use strict;

use Codestriker::DB::DBI;

# Create a User object from an existing record in the database.
sub new {
    my ($class, $email) = @_;
    my $self = {};

    $self->{email} = $email;

    # Retrieve the specific user record.
    my $dbh = Codestriker::DB::DBI->get_connection();
    eval {
        my $select_user =
          $dbh->prepare_cached('SELECT password_hash, admin ' .
                               'FROM usertable ' .
                               'WHERE email = ?');
        $select_user->execute($email);

        my ($password_hash, $admin) = $select_user->fetchrow_array();
        $select_user->finish();

        $self->{password_hash} = $password_hash;
        $self->{admin} = $admin;
    };
    my $success = $@ ? 0 : 1;

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;

    # Return the user record found.
    bless $self, $class;
    return $self;
}

# Update an existing user record with a new password.
sub update_password {
    my ($self, $new_password) = @_;

    my $password_hash = _hash_password($new_password);
    my $dbh = Codestriker::DB::DBI->get_connection();
    eval {
        my $update_user =
          $dbh->prepare_cached('UPDATE usertable SET password_hash = ? ' .
                               'WHERE email = ?');
        $update_user->execute($password_hash, $self->{email});
    };
    my $success = $@ ? 0 : 1;

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;

    $self->{password_hash} = $password_hash;
}

# Update an existing user record with new admin status.
sub update_admin {
    my ($self, $new_admin) = @_;

    my $dbh = Codestriker::DB::DBI->get_connection();
    eval {
        my $update_user =
          $dbh->prepare_cached('UPDATE usertable SET admin = ? ' .
                               'WHERE email = ?');
        $update_user->execute($new_admin, $self->{email});
    };
    my $success = $@ ? 0 : 1;

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;

    $self->{admin} = $new_admin;
}

# Create a new user into the database with all of the specified properties.
# Return the new password which has been assigned to the user.
sub create {
    my ($type, $email, $admin) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Create a random password for the new user.
    my $new_password = _create_random_password();
    my $password_hash = _hash_password($new_password);

    # Insert the row into the database.
    eval {
        my $insert_user =
          $dbh->prepare_cached('INSERT INTO usertable (email, password_hash, admin) ' .
                               'VALUES (?, ?, ?)');

        $insert_user->execute($email, $password_hash, $admin);
    };
    my $success = $@ ? 0 : 1;

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;

    # Return the password that was created.
    return $new_password;
}

# Determine if the specific user already exists.
sub exists {
    my ($type, $email) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    my $count = 0;
    eval {
        my $select_email =
          $dbh->prepare_cached('SELECT COUNT(*) FROM usertable ' .
                               'WHERE email = ?');
        $select_email->execute($email);
        ($count) = $select_email->fetchrow_array();
        $select_email->finish();
    };
    my $success = $@ ? 0 : 1;

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;

    return $count;
}

# Method for producing a hash from a password.
sub _hash_password {
    my ($password) = @_;

    # List of characters that can be used for the salt.
    my @salt_characters = ( '.', '/', 'A'..'Z', 'a'..'z', '0' ..'9' );

    # Generate the salt.  Generate an 8 character value in case we are on
    # a system which uses MD5 digests (48 bit - 6 * 8).  Older systems just
    # use the first two characters.
    my $salt = '';
    for (my $i = 0; $i < 8; $i++) {
        $salt .= $salt_characters[rand(64)];
    }

    # Crypt the password.
    my $cryptedpassword = crypt($password, $salt);

    # Return the crypted password.
    return $cryptedpassword;
 }

# Method for creating a random password consisting of alphanumeric
# characters.
sub _create_random_password {
    my @password_characters = ( 'A'..'Z', 'a'..'z', '0' ..'9' );
    return join("", map{ $password_characters[rand 62] } (1..8));
}

1;
