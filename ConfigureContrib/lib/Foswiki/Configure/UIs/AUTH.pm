# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::UIs::AUTH

Specialised UI for the AUTH screen. This implements a special method that
is used by =configure= to filter out certain URL parameters (the
passwords), and pass through all others as CGI::hidden.

=cut

package Foswiki::Configure::UIs::AUTH;

use strict;
use warnings;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');

my %nonos = (
    cfgAccess => 1,
    newCfgP   => 1,
    confCfgP  => 1,
);

=begin TML

---++ ObjectMethod params() -> $html

Called to generate HTML for the URL parameters, filtering out sensitive
password parameters.

=cut

sub params {
    my ($this) = @_;

    my @params = ();

    # Pass URL params through, except those below
    foreach my $param ( $Foswiki::Configure::query->param ) {
        next if ( $nonos{$param} );
        my @values = $Foswiki::Configure::query->param($param);
        foreach my $value (@values) {
            push( @params, Foswiki::Configure::UI::hidden( $param, $value ) );
        }
    }
    return @params;
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
