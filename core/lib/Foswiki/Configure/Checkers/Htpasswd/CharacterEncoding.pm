# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Htpasswd::CharacterEncoding;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    if ( $Foswiki::cfg{Htpasswd}{CharacterEncoding} ) {

        # Test if this is actually an available encoding:
        eval {
            require Encode;
            Encode::encode( $Foswiki::cfg{Htpasswd}{CharacterEncoding},
                'test', 0 );
        };
        if ($@) {
            $reporter->ERROR("Unknown store character set requested.");
            print STDERR "encode failed $@ \n";
            return;
        }

        if ( $Foswiki::cfg{Htpasswd}{CharacterEncoding} =~
m/^(?:iso-?2022-?|hz-?|gb2312|gbk|gb18030|.*big5|.*shift_?jis|ms.kanji|johab|uhc)/i
          )
        {

            $reporter->ERROR(
                <<HERE
Cannot use this multi-byte encoding ('$Foswiki::cfg{Htpasswd}{CharacterEncoding}')
as {Htpasswd}{CharacterEncoding}. Please set a different character encoding setting.
HERE
            );
        }

        # Extract the character set from locale for consistency check
        my $charset;
        $Foswiki::cfg{Site}{Locale} =~ m/\.([a-z0-9_-]+)$/i;
        $charset = $1 || '';    # no guess?
        $charset =~ s/^utf8$/utf-8/i;
        $charset =~ s/^eucjp$/euc-jp/i;
        $charset = lc($charset);

        if ( $charset
            && ( lc( $Foswiki::cfg{Htpasswd}{CharacterEncoding} ) ne $charset )
          )
        {
            $reporter->ERROR(
                <<HERE
The Character set determined by the configured Locale, and this character set,
are inconsistent.  Recommended setting:  =$charset=
HERE
            );
        }
    }

    if ( $Foswiki::cfg{isBOOTSTRAPPING} ) {
        if (
            !$Foswiki::cfg{Htpasswd}{CharacterEncoding}
            || (
                lc(
                    $Foswiki::cfg{Htpasswd}{CharacterEncoding} ne 'iso-8859-1'
                )
            )
          )
        {
            $reporter->WARN( <<HERE );
The BOOTSTRAP process has left the =.htpasswd= file character set encoding as utf-8.
In most systems this should work fine.  However if you are migrating existing data 
and have user information that doesn't map to utf-8, you should set this field to
the encoding used in your existing system.  In most cases this will be =iso-8859-1=.
Only set this if errors are encountered when processing your existing password file.
HERE
        }
    }

    return '';
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
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
