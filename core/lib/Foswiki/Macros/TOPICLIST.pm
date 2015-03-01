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

sub TOPICLIST {
    my ( $this, $params ) = @_;
    my $format = $params->{_DEFAULT} || $params->{'format'} || '$topic';
    my $separator = $params->{separator} || "\n";
    $separator =~ s/\$n/\n/;
    my $selection = $params->{selection} || '';
    $selection =~ s/\,/ /g;
    $selection = " $selection ";
    my $marker = $params->{marker} || 'selected="selected"';

    my $web = $params->{web} || $this->{webName};
    $web =~ s#\.#/#g;

    my $webObject = Foswiki::Meta->new( $this, $web );
    my $thisWebNoSearchAll =
      Foswiki::isTrue( $webObject->getPreference('NOSEARCHALL') );
    return ''
      if !defined( $params->{web} )
      && $web ne $this->{webName}
      && $thisWebNoSearchAll;

    return '' unless $webObject->haveAccess();

    my @items;
    my $it = $webObject->eachTopic();
    while ( $it->hasNext() ) {
        my $item = $it->next();

        my $topicObject = Foswiki::Meta->new( $this, $web, $item );
        next unless $topicObject->haveAccess("VIEW");

        my $line = $format;
        $line =~ s/\$web\b/$web/g;
        $line =~ s/\$topic\b/$item/g;
        $line =~ s/\$name\b/$item/g;     # Undocumented, DO NOT REMOVE
        $line =~ s/\$qname/"$item"/g;    # Undocumented, DO NOT REMOVE
        my $mark = ( $selection =~ m/ \Q$item\E / ) ? $marker : '';
        $line =~ s/\$marker/$mark/g;
        $line = expandStandardEscapes($line);
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
