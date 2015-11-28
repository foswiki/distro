package Foswiki::Configure::Checkers::RCSChecker;
use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use strict;
use warnings;
use Assert;

use constant REQUIRED_RCS_VERSION => 5.7;

=begin TML

---++ PROTECTED ObjectMethod checkRCSProgram($prog) -> $html
Specific to RCS, this method checks that the given program is available.
Check is only activated when the selected store implementation is RcsWrap.

=cut

sub checkRCSProgram {
    my ( $this, $key ) = @_;

    return 'rcs IS NOT USED IN THIS CONFIGURATION'
      unless $Foswiki::cfg{Store}{Implementation} eq 'Foswiki::Store::RcsWrap';

    my $mess = '';
    my $err  = '';
    my $prog = $Foswiki::cfg{RCS}{$key} || '';
    my $version;
    my $fullversion;

    $prog =~ s/^\s*(\S+)\s.*$/$1/;    # Extract out program name and untaint
    $prog =~ m/^(.*)$/;
    $prog = $1;

    if ( !$prog ) {
        $err .= $key . ' is not set';
    }
    else {
        foreach my $cmd ( "$prog --version", "$prog -V" ) {
            my $msg;

            # Don't let failures get trapped.
            {
                local $SIG{'__WARN__'};
                local $SIG{'__DIE__'};
                $msg = `$cmd 2>&1` || "";
            }

            #print STDERR "$cmd returned $?, " . ( $msg || 'undef' ) . "\n";

            if ( $? < 0 ) {
                $err .=
"RCS command $prog failed, may not be installed, or found on path. ";
                last;
            }
            elsif ( $? > 0 ) {

                # Probably a syntax error eg.  --version not supported
                next;
            }
            elsif ( defined $msg
                && $msg =~ m/^.*?([0-9]+\.[0-9]+)(\.[0-9]+)?$/m )
            {
                $version = $1 if defined($1);
                $fullversion = $1 . ( $2 || '' ) if defined($1);
                last unless DEBUG;
            }

        }

        ASSERT( REQUIRED_RCS_VERSION =~ m/^\d+(\.\d+)?$/ ) if DEBUG;

        if ( !defined $version ) {
            $err .= "Unable to determine version of $prog. ";
        }
        elsif ( $version < REQUIRED_RCS_VERSION ) {

            # RCS too old
            $err .=
                $prog
              . ' is too old, upgrade to version '
              . REQUIRED_RCS_VERSION
              . ' or higher. ';
        }
    }

    $mess .= $this->NOTE("$prog $fullversion detected.") if defined $fullversion;

    if ($err) {
        $mess .= $this->ERROR(
            $err . <<'HERE'
Foswiki will probably not work with this RCS setup. Either correct the setup, or
switch to RcsLite. To enable RCSLite you need to change the setting of
{Store}{Implementation} to 'Foswiki::Store::RcsLite'.
HERE
        );
    }
    return $mess;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
