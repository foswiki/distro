# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::URLPATH;

use strict;
use warnings;

require Foswiki::Configure::Checkers::URL;
our @ISA = ('Foswiki::Configure::Checkers::URL');

# CHECK= options
#  expand
#  parts, partsreq = query, fragment (path is required)

sub check {
    my $this   = shift;
    my $valobj = shift;

    my @optionList = ( @_ ? @_ : $this->parseOptions() );

    $optionList[0] = {} unless (@optionList);

    my $e = '';
    $e .= $this->ERROR(".SPEC error: multiple CHECK options for NUMBER")
      if ( @optionList > 1 );

    my $options = $optionList[0];

    $options = {
        expand => $options->{expand},
        nullok => $options->{nullok},
        parts  => [
            'path',
            $options->{parts}
            ? ( grep $_ =~ /^(?:query|fragment)$/, @{ $options->{parts} } )
            : ()
        ],
        partsreq => [
            'path',
            $options->{partsreq}
            ? ( $_ =~ /^(?:query|fragment)$/, @{ $options->{partsreq} } )
            : ()
        ],
        schemes  => [],
        authtype => [],
    };

    return $e . $this->SUPER::check( $valobj, $options );
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
