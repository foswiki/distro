# See bottom of file for license and copyright information
package Foswiki::Users::ApacheHtpasswdUser;
use base 'Foswiki::Users::Password';

use Apache::Htpasswd;
use Assert;
use strict;
use Foswiki::Users::Password;
use Error qw( :try );

=begin TML

---+ package Foswiki::Users::ApacheHtpasswdUser

Password manager that uses Apache::HtPasswd to manage users and passwords.

Subclass of =[[%SCRIPTURL{view}%/%SYSTEMWEB%/PerlDoc?module=Foswiki::Users::Password][Foswiki::Users::Password]]=.
See documentation of that class for descriptions of the methods of this class.

Duplicates functionality of
=[[%SCRIPTURL{view}%/%SYSTEMWEB%/PerlDoc?module=Foswiki::Users::HtPasswdUser][Foswiki::Users::HtPasswdUser]]=;
provided mainly as an example of how to write a new password manager.

=cut

sub new {
    my ( $class, $session ) = @_;

    my $this = $class->SUPER::new($session);
    $this->{apache} =
      new Apache::Htpasswd( { passwdFile => $Foswiki::cfg{Htpasswd}{FileName} } );

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{apache};
}

=begin TML

---++ ObjectMethod readOnly(  ) -> boolean

returns true if the password file is not currently modifyable

=cut

sub readOnly {
    my $this = shift;
    my $path = $Foswiki::cfg{Htpasswd}{FileName};

    #TODO: what if the data dir is also read only?
    if ( ( !-e $path ) || ( -e $path && -r $path && !-d $path && -w $path ) ) {
        $this->{session}->enterContext('passwords_modifyable');
        return 0;
    }
    return 1;
}

sub canFetchUsers {
    return 1;
}

sub fetchUsers {
    my $this  = shift;
    my @users = $this->{apache}->fetchUsers();
    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@users );
}

sub fetchPass {
    my ( $this, $login ) = @_;
    ASSERT($login) if DEBUG;
    my $r = $this->{apache}->fetchPass($login);
    $this->{error} = undef;
    return $r;
}

sub checkPassword {
    my ( $this, $login, $passU ) = @_;
    ASSERT($login) if DEBUG;

    my $r = $this->{apache}->htCheckPassword( $login, $passU );
    $this->{error} = $this->{apache}->error();
    return $r;
}

sub removeUser {
    my ( $this, $login ) = @_;
    ASSERT($login) if DEBUG;

    $this->{error} = undef;

    #don't ask to remove a user that does not exist - Apache::Htpasswd carpsA
    unless ( $this->{apache}->fetchPass($login) ) {
        $this->{error} = "User does not exist";
        return;
    }

    my $r;
    try {
        $r = $this->{apache}->htDelete($login);
        $this->{error} = $this->{apache}->error() unless ( defined($r) );
    }
    catch Error::Simple with {
        $this->{error} = $this->{apache}->error();
    };
    return $r;
}

sub setPassword {
    my ( $this, $login, $newPassU, $oldPassU ) = @_;
    ASSERT($login) if DEBUG;

    if ( defined($oldPassU) ) {
        my $ok = 0;
        try {
            $ok = $this->{apache}->htCheckPassword( $login, $oldPassU );
        }
        catch Error::Simple with {};
        unless ($ok) {
            $this->{error} = "Wrong password";
            return 0;
        }
    }

    my $added = 0;
    try {
        $added = $this->{apache}->htpasswd( $login, $newPassU, $oldPassU );
        $this->{error} = undef;
    }
    catch Error::Simple with {
        $this->{error} = $this->{apache}->error();
        $this->{error} = undef
          if $this->{error} && $this->{error} =~ /assword not changed/;
    };

    return $added;
}

sub encrypt {
    my ( $this, $login, $passwordU, $fresh ) = @_;
    ASSERT($login) if DEBUG;

    my $salt = '';
    unless ($fresh) {
        my $epass = $this->fetchPass($login);
        $salt = substr( $epass, 0, 2 ) if ($epass);
    }
    my $r = $this->{apache}->CryptPasswd( $passwordU, $salt );
    $this->{error} = $this->{apache}->error();
    return $r;
}

sub error {
    my $this = shift;
    return $this->{error} || undef;
}

sub isManagingEmails {
    return 1;
}

# emails are stored in extra info field as a ; separated list
sub getEmails {
    my ( $this, $login ) = @_;
    my @r = split( /;/, $this->{apache}->fetchInfo($login) );
    $this->{error} = $this->{apache}->error() || undef;
    return @r;
}

sub setEmails {
    my $this  = shift;
    my $login = shift;
    my $r     = $this->{apache}->writeInfo( $login, join( ';', @_ ) );
    $this->{error} = $this->{apache}->error() || undef;
    return $r;
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2004-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
