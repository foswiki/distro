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
    my ( $this, $params, $path2Object, $relative ) = @_;
    my ( $path1, $path2, $script );

    $script = $params->{_DEFAULT};

    if ( defined $script && substr( $script, 0, 4 ) eq 'rest' ) {
        if ( defined $params->{subject} ) {
            $path1 = $params->{subject};
            delete $params->{subject};
        }
        if ( defined $params->{verb} ) {
            $path2 = $params->{verb};
            delete $params->{verb};
        }
    }
    elsif ( defined $script && $script eq 'jsonrpc' ) {
        if ( defined $params->{namespace} ) {
            $path1 = $params->{namespace};
            delete $params->{namespace};
        }
        if ( defined $params->{method} ) {
            $path2 = $params->{method};
            delete $params->{method};
        }
    }
    else {
        if ( defined $params->{topic} ) {
            my @path = split( /[\/.]+/, $params->{topic} );
            $path2 = pop(@path) if scalar(@path);
            if ( scalar(@path) ) {
                $path1 = join( '/', @path )
                  ;    # web= is ignored, so preserve it in the query string
            }
            else {
                $path1 = $params->{web};
                delete $params
                  ->{web};    # web= used, so drop the duplicate query param.
            }
            delete $params->{topic};
        }
        elsif ( defined $params->{web} ) {
            $path1 = $params->{web};
            delete
              $params->{web};    # web= used, so drop the duplicate query param.
        }
    }

    my @p =
      map { $_ => $params->{$_} }
      grep { !/^(_.*|path)$/ }
      keys %$params;

    if ( defined $script && scalar @p ) {
        if ( substr( $script, 0, 4 ) eq 'rest' && ( !$path1 || !$path2 ) ) {
            return
"<div class='foswikiAlert'>$script requires both 'subject' and 'verb' parameters if other parameters are supplied.</div>";
        }
        if ( $script eq 'jsonrpc' && !$path1 && scalar @p ) {
            return
"<div class='foswikiAlert'>$script requires the 'namespace' parameter if other parameters are supplied.</div>";
        }
    }

    return $this->getScriptUrl( !$relative, $script, $path1, $path2, @p );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2015-2016 Foswiki Contributors. Foswiki Contributors
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
