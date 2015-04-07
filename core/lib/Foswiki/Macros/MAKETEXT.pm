# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

use Locale::Maketext;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub MAKETEXT {
    my ( $this, $params ) = @_;

    my $str = $params->{_DEFAULT} || $params->{string} || "";
    return "" unless $str;

    # escape everything:
    $str =~ s/\[/~[/g;
    $str =~ s/\]/~]/g;

    # restore already escaped stuff:
    $str =~ s/~~+\[/~[/g;
    $str =~ s/~~+\]/~]/g;

    my $max         = 0;
    my $min         = 1;
    my $param_error = 0;

    # unescape parameters and calculate highest parameter number:
    $str =~ s/~\[(\_(\d+))~\]/_validate($1, $2, $max, $min, $param_error)/ge;
    $str =~
s/~\[(\*,\_(\d+),[^,]+(,([^,]+))?)~\]/ _validate($1, $2, $max, $min, $param_error)/ge;
    return $str if ($param_error);

    # get the args to be interpolated.
    my $argsStr = $params->{args} || "";

    # Escape any escapes.
    $str =~ s#\\#\\\\#g
      if ( $Foswiki::cfg{UserInterfaceInternationalisation}
        && $Locale::Maketext::VERSION
        && $Locale::Maketext::VERSION < 1.23 );    # escape any escapes

    my @args = split( /\s*,\s*/, $argsStr );

    # fill omitted args with empty strings
    while ( ( scalar(@args) ) < $max ) {
        push( @args, '' );
    }

    # do the magic:
    my $result = $this->i18n->maketext( $str, @args );

    # replace accesskeys:
    $result =~
      s#(^|[^&])&([a-zA-Z])#$1<span class='foswikiAccessKey'>$2</span>#g;

    # replace escaped amperstands:
    $result =~ s/&&/\&/g;

    return $result;
}

sub _validate {

    #my ( $contents, $number, $max, $min, $param_error ) = @_

    $_[2] = $_[1] if ( $_[1] > $_[2] );    # Record maximum param number
    $_[3] = $_[1] if ( $_[1] < $_[3] );    # Record minimum param number

    if ( $_[1] > 100 ) {
        $_[4] = 1;                         # Set error flag
        return
"<span class=\"foswikiAlert\">Excessive parameter number $_[2], MAKETEXT rejected.</span>";
    }
    if ( $_[1] < 1 ) {
        $_[4] = 1;                         # Set error flag
        return
"<span class=\"foswikiAlert\">Invalid parameter <code>\"$_[0]\"</code>, MAKETEXT rejected.</span>";
    }
    return "[$_[0]]";    # Return the complete bracket parameter without escapes
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
