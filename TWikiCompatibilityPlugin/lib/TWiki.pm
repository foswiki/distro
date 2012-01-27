# See bottom of file for license and copyright information
#package TWiki;

use strict;
use warnings;

use Foswiki;

sub TWiki::new {
    my ( $this, $loginName, $query, $initialContext ) = @_;
    if ( !$Foswiki::Plugins::SESSION && UNIVERSAL::isa( $query, 'CGI' ) ) {

        ## Compatibility: User gave a CGI object
        ## This probably means we're inside a script
        ## $query = undef;
        # The above was added in Item689, Foswikirev:1847. It doesn't make any
        # sense to me. PH disabled under Item11431 ('no singleton left behind')
    }
    my $fatwilly = new Foswiki( $loginName, $query, $initialContext );
    require TWiki::Sandbox;
    $fatwilly->{sandbox} = new TWiki::Sandbox();
    return $fatwilly;
}

*TWiki::regex = \%Foswiki::regex;
*TWiki::cfg   = \%Foswiki::cfg;

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
