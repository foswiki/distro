# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::LanguageFileCompression;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;

    return '';
}

# When compression state changes, run feedback for all enabled languages
# to create or remove compressed string files.
#
# Disabled languages will be handled if they are ever enabled - based on the
# value of LanguageFileCompression at that time.

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    my $e = '';

    if ( $Foswiki::cfg{UserInterfaceInternationalisation} && wantarray ) {
        my $keys = ref($valobj) ? $valobj->{keys} : $valobj
          or die "No keys for value";

        my $enabled = $this->getItemCurrentValue($keys);

        my @keys;
        foreach my $key ( keys %{ $Foswiki::cfg{Languages} } ) {
            my $ekey = $key;
            $ekey = "'$key'" if ( $ekey =~ /\W/ );
            $ekey = "{Languages}{$ekey}{Enabled}";
            push @keys, $ekey
              if ( $this->getItemCurrentValue($ekey) );
        }

        return ( $e, [@keys] );
    }

    return wantarray ? ( $e, 0 ) : $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

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
