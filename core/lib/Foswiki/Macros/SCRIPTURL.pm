# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

use Foswiki::Macros::SCRIPTURLPATH;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub SCRIPTURL {
    my ( $this, $params, $topicObject, $relative ) = @_;
    my @p =
      map { $_ => $params->{$_} }
      grep { !/^(_.*|path)$/ }
      keys %$params;
    my $script = $params->{_DEFAULT};
    my ( $web, $topic );
    if ( defined $params->{path} ) {
        my @path = split( /[\/.]+/, $params->{path} );
        $topic = scalar( @path > 1 ) ? pop(@path) : undef;
        $web = join( '/', @path );
    }
    return $this->getScriptUrl( !$relative, $script, $web, $topic, @p );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2015 Foswiki Contributors. Foswiki Contributors
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
