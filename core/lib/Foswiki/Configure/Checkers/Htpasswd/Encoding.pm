# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Htpasswd::Encoding;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Dependency;

sub check {
    my $this = shift;
    my $e    = '';

    if ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'md5' ) {
        $Foswiki::cfg{Htpasswd}{Encoding} = 'htdigest-md5';
        $e .=
          $this->guessed()
          . $this->WARN(
'Encoding has been changed from the deprecated <tt>md5</tt> setting to <tt>htdigest-md5</tt>.  Please save your configuration. Note that this does not change how your passwords are stored.'
          );
    }
    my $enc = $Foswiki::cfg{Htpasswd}{Encoding};

    if ( $Foswiki::cfg{Htpasswd}{AutoDetect} || $enc eq 'crypt' ) {
        my $f = $Foswiki::cfg{Htpasswd}{FileName};
        Foswiki::Configure::Load::expandValue($f);

        if ( $enc eq 'crypt' ) {
            if ( $Foswiki::cfg{Htpasswd}{AutoDetect} && -f $f ) {
                $e .= $this->WARN(
'<b>Not recommended</b> crypt encoding only uses the first 8 characters of the password and silently ignores the rest.  <tt>{AutoDetect}</tt> is enabled.  Consider changing this to stronger encoding. Passwords will migrate to the new encoding as users change their passwords.'
                );
            }
            elsif ( -f $f ) {
                $e .= $this->WARN(
'<b>Not Recommended:</b> crypt encoding only uses the first 8 characters of the password and silently ignores the rest.  However changing Encoding will invalidate existing passwords unless <tt>AutoDetect</tt> is enabled. See <a href="http://foswiki.org/Support/HtPasswdEncodingSupplement">HtPasswdEncodingSupplement</a> for more information'
                );
            }
            else {
                $e .= $this->ERROR(
'crypt encoding only uses the first 8 characters of the password and silently ignores the rest.  No password file exists, so now is a good time choose a different encoding. See <a href="http://foswiki.org/Support/HtPasswdEncodingSupplement">HtPasswdEncodingSupplement</a> for more information'
                );
            }
        }
    }

    my $check = {
        'Digest::MD5'                => ['htdigest-md5'],
        'Digest::SHA'                => ['sha1'],
        'Crypt::PasswdMD5'           => [ 'apache-md5', 'crypt-md5' ],
        'Crypt::Eksblowfish::Bcrypt' => ['bcrypt'],
    };

    foreach my $mod ( sort keys %$check ) {
        $e .= $this->_checkPerl( $mod, $check->{$mod} );
    }

    if ( $Foswiki::cfg{Htpasswd}{AutoDetect} || $enc eq 'crypt-md5' ) {
        use Config;
        if ( $Config{myuname} =~ /strawberry/i ) {
            my $n = $this->checkPerlModule(
                'Crypt::PasswdMD5',
"Required for crypt-md5 encoding on Windows with Strawberry perl",
                0
            );

            if ( $n =~ m/Not installed/ ) {
                $e .= $this->ERROR($n);
            }
        }
    }

    if (   $enc ne 'crypt'
        && $enc ne 'apache-md5'
        && $Foswiki::cfg{PasswordManager} eq
        'Foswiki::Users::ApacheHtpasswdUser' )
    {
        $e .= $this->ERROR(
"PasswordManager ApacheHtpasswdUser only supports crypt and apache-md5 encryption.  Use HtPasswdUser for other Encoding types."
        );
    }

    return $e;
}

sub _checkPerl {
    my ( $this, $module, $method_list ) = @_;
    my $note = '';
    my $n;
    my $err   = 0;
    my $mlist = '';

    $n =
      $this->checkPerlModule( $module, "Required to use or autodetect: XENC ",
        0 );

    foreach my $method (@$method_list) {
        $err = 1 if ( $Foswiki::cfg{Htpasswd}{Encoding} eq $method );
    }
    $mlist = join( ', ', @$method_list );

    $n =~ s/XENC/<tt>$mlist<\/tt> encoding./;

    if ( $n =~ m/Not installed/ && $err ) {
        $note .= $this->ERROR($n);
    }
    elsif ( $n =~ m/Not installed/ && $Foswiki::cfg{Htpasswd}{AutoDetect} ) {
        $note .= $this->WARN($n);
    }
    else {
        $note .= $this->NOTE($n);
    }

    return $note;
}
1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
