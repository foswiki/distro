# See bottom of file for license and copyright information
package Foswiki::Users::ApacheHtpasswdUser;
use strict;
use warnings;

use Foswiki::Users::Password ();
our @ISA = ('Foswiki::Users::Password');

use Assert;
use Error qw( :try );

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

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
    my $UseMD5;

    #my $UsePlain;

    eval 'use Apache::Htpasswd';
    if ($@) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        print STDERR
"ERROR:  Missing CPAN Module Apache::Htpasswd -  $mess - Consider using Foswiki::Users::HtpasswdUser for password manager\n";
        throw Error::Simple(
"ERROR:  Missing CPAN Module Apache::Htpasswd - $mess - Consider using Foswiki::Users::HtpasswdUser for password manager"
        );
    }
    if ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'crypt' ) {
        if ( $^O =~ /^MSWin/i ) {
            print STDERR "ERROR: {Htpasswd}{Encoding} setting : "
              . $Foswiki::cfg{Htpasswd}{Encoding}
              . " Not supported on Windows.  Recommend using HtPasswdUser if crypt is required.\n";
            throw Error::Simple( "ERROR: {Htpasswd}{Encoding} setting : "
                  . $Foswiki::cfg{Htpasswd}{Encoding}
                  . " Not supported on Windows.  Recommend using HtPasswdUser if crypt is required.\n"
            );
        }
    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'apache-md5' ) {
        require Crypt::PasswdMD5;
        $UseMD5 = 1;
    }

    # SMELL: Apache::Htpasswd doesn't really write out plain passwords
    # so no sense enabling support for this.
    #elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'plain' ) {
    #    $UsePlain = 1;
    #}
    else {
        print STDERR "ERROR: {Htpasswd}{Encoding} setting : "
          . $Foswiki::cfg{Htpasswd}{Encoding}
          . " unsupported by ApacheHdpasswduser.  Recommend using HtPasswdUser.\n";
        throw Error::Simple( "ERROR: {Htpasswd}{Encoding} setting : "
              . $Foswiki::cfg{Htpasswd}{Encoding}
              . " unsupported by ApacheHdpasswduser.  Recommend using HtPasswdUser.\n"
        );
    }

    my $this = $class->SUPER::new($session);
    $this->{apache} = new Apache::Htpasswd(
        {
            passwdFile => $Foswiki::cfg{Htpasswd}{FileName},
            UseMD5     => $UseMD5,

            #UsePlain   => $UsePlain,
        }
    );
    unless ( -e $Foswiki::cfg{Htpasswd}{FileName} ) {

        # apache doesn't create the file, so need to init it
        my $F;
        open( $F, '>', $Foswiki::cfg{Htpasswd}{FileName} ) || die $!;
        print $F "";
        close($F);
    }

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

    # We expect the path to exist and be writable.
    return 0 if ( -e $path && -f _ && -w _ );

    # Otherwise, log a problem.
    $this->{session}->logger->log( 'warning',
            'The password file does not exist or cannot be written.'
          . 'Run =configure= and check the setting of {Htpasswd}{FileName}.'
          . ' New user registration has been disabled until this is corrected.'
    );

    # And disable registration (and password changes)
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 0;
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

    if ( defined($oldPassU) && $oldPassU ne '1' ) {
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
        if ( defined($oldPassU) && $oldPassU eq '1' ) {
            $added =
              $this->{apache}
              ->htpasswd( $login, $newPassU, { 'overwrite' => 1 } );
        }
        else {
            $added = $this->{apache}->htpasswd( $login, $newPassU, $oldPassU );
        }
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

 # Salt is 14 because on Windows, CryptPasswd will use the Apache MD5 algorithm
 # $apr1$ssssssss$, but uses Crypt on Linux with 2 character salt.  need to pass
 # longest possible salt.
        $salt = substr( $epass, 0, 14 ) if ($epass);
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

# Searches the password DB for users who have set this email.
sub findUserByEmail {
    my ( $this, $email ) = @_;
    my $logins = [];

    $email = lc($email);

    # read passwords with shared lock
    my @users = $this->{apache}->fetchUsers();
    foreach my $login (@users) {
        my %ems = map { lc($_) => 1 } $this->getEmails($login);
        if ( $ems{$email} ) {
            push( @$logins, $login );
        }
    }
    return $logins;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2004-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
