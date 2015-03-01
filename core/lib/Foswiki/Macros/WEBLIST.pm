# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub WEBLIST {
    my ( $this, $params ) = @_;

    # List of webs to consider; default is all public webs
    my $webs = $params->{webs} || 'public';
    my @webslist = split( /,\s*/, $webs );

    # Modifier on "public" and "webtemplate" pseudo-webs
    my $rootWeb = $params->{subwebs};

    # the web= parameter, *not* the web being listed
    my $web = $params->{web} || '';
    $web =~ s#\.#/#g;

    # Output format
    my $format = $params->{_DEFAULT} || $params->{'format'} || '$name';
    $format ||= '$name';

    my $separator = $params->{separator} || "\n";
    $separator = Foswiki::expandStandardEscapes($separator);

    my $selection = $params->{selection} || '';
    $selection =~ s/\,/ /g;
    $selection = " $selection ";

    my $marker = $params->{marker} || 'selected="selected"';

    my @list = ();
    foreach my $aweb (@webslist) {
        if ( $aweb =~ m/^(public|webtemplate)$/ ) {
            require Foswiki::WebFilter;
            my $filter;
            if ( $aweb eq 'public' ) {
                $filter = new Foswiki::WebFilter('user,public,allowed');
            }
            elsif ( $aweb eq 'webtemplate' ) {
                $filter = new Foswiki::WebFilter('template,allowed');
            }
            push( @list, $this->deepWebList( $filter, $rootWeb ) );
        }
        else {
            push( @list, $aweb ) if ( $this->webExists($aweb) );
        }
    }

    my @items;
    foreach my $item (@list) {
        my $line = $format;
        $line =~ s/\$web\b/$web/g;
        $line =~ s/\$name\b/$item/g;
        $line =~ s/\$qname/"$item"/g;
        my $indenteditem = $item;
        $indenteditem =~ s#/$##g;
        $indenteditem =~ s#\w+/#%TMPL:P{"webListIndent"}%#g;
        $line         =~ s/\$indentedname/$indenteditem/g;
        my $mark = ( $selection =~ m/ \Q$item\E / ) ? $marker : '';
        $line =~ s/\$marker/$mark/g;
        $line = Foswiki::expandStandardEscapes($line);
        push( @items, $line );
    }
    return join( $separator, @items );
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
