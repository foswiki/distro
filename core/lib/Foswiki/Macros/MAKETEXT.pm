# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

my $max;
my $min;
my $param_error;

sub MAKETEXT {
    my ( $this, $params ) = @_;

    my $str = $params->{_DEFAULT} || $params->{string} || "";
    return "" unless $str;

    # escape everything:
    $str =~ s/\[/~[/g;
    $str =~ s/\]/~]/g;

    # restore already escaped stuff:
    $str =~ s/~~\[/~[/g;
    $str =~ s/~~\]/~]/g;

    $max         = 0;
    $min         = 1;
    $param_error = 0;

    # unescape parameters and calculate highest parameter number:
    $str =~ s/~\[(\_(\d+))~\]/_validate($1, $2)/ge;
    $str =~ s/~\[(\*,\_(\d+),[^,]+(,([^,]+))?)~\]/ _validate($1, $2)/ge;
    return $str if ($param_error);

    $str =~ s#\\#\\\\#g;

    # get the args to be interpolated.
    my $argsStr = $params->{args} || "";

    my @args = split( /\s*,\s*/, $argsStr );

    # fill omitted args with empty strings
    while ( ( scalar @args ) < $max ) {
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
    $max = $_[1] if ( $_[1] > $max );
    $min = $_[1] if ( $_[1] < $min );
    if ( $_[1] > 100 ) {
        $param_error = 1;
        return
"<span class=\"foswikiAlert\">Excessive parameter number $max, MAKETEXT rejected.</span>";
    }
    if ( $_[1] < 1 ) {
        $param_error = 1;
        return
"<span class=\"foswikiAlert\">Invalid parameter <code>\"$_[0]\"</code>, MAKETEXT rejected.</span>";
    }
    return "[$_[0]]";
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
