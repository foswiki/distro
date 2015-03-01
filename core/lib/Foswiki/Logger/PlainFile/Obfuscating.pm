# See bottom of file for license and copyright information
package Foswiki::Logger::PlainFile::Obfuscating;

use strict;
use warnings;
use Assert;

use Foswiki::Logger            ();
use Foswiki::Logger::PlainFile ();
use Foswiki::Configure::Load;
use Digest::MD5 qw( md5_hex );

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

our @ISA = ('Foswiki::Logger::PlainFile');

=begin TML

---+ package Foswiki::Logger::PlainFile::Obfuscating

Plain file implementation of the Foswiki Logger interface, with obfuscation
of IP addresses.  See Foswiki::Logger::PlainFile for further details.
This implementation only implements log() call.

This logger implementation maps groups of levels to a single logfile, viz.
   * =debug= messages are output to $Foswiki::cfg{Log}{Dir}/debug.log
   * =info= messages are output to $Foswiki::cfg{Log}{Dir}/events.log
   * =warning=, =error=, =critical=, =alert=, =emergency= messages are
     output to $Foswiki::cfg{Log}{Dir}/error.log.
   * =error=, =critical=, =alert=, and =emergency= messages are also
     written to standard error (the webserver log file, usually)

=cut

sub new {
    my $class = shift;
    return bless( {}, $class );
}

=begin TML

---++ ObjectMethod log($level, @fields)

See Foswiki::Logger for the interface.

=cut

sub log {

    #my ( $this, $level, @fields ) = @_;
    my $this = shift;

    #foreach my $field ( @_ )  {
    #    print STDERR "field $field \n";
    #    }

    if ( @_ > 4 ) {
        unless ( $_[4] =~ m/^AUTHENTICATION FAILURE/ ) {

            if ( $Foswiki::cfg{Log}{Obfuscating}{MaskIP} ) {
                $_[5] = 'x.x.x.x';
            }
            else {
                my $md5hex = md5_hex( $_[5] );
                $_[5] =
                    hex( substr( $md5hex, 0, 2 ) ) . '.'
                  . hex( substr( $md5hex, 2, 2 ) ) . '.'
                  . hex( substr( $md5hex, 4, 2 ) ) . '.'
                  . hex( substr( $md5hex, 6, 2 ) );
            }
        }
    }

    $this->SUPER::log(@_);
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
