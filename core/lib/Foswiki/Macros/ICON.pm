# See bottom of file for license and copyright information
package Foswiki;

use strict;

# Maps from a filename (or just the extension) to the name of the
# file that contains the image for that file type.
sub mapToIconFileName {
    my ( $this, $fileName, $default ) = @_;

    my @bits = ( split( /\./, $fileName ) );
    my $fileExt = lc( $bits[$#bits] );

    unless ( $this->{_ICONMAP} ) {
        my $iconTopic = $this->{prefs}->getPreference('ICONTOPIC');
        if ( defined($iconTopic) ) {
            my ( $web, $topic ) =
              $this->normalizeWebTopicName( $this->{webName}, $iconTopic );
            my $topicObject = Foswiki::Meta->new( $this, $web, $topic );
            local $/;
            try {
                my $icons =
                  $topicObject->openAttachment( '_filetypes.txt', '<' );
                %{ $this->{_ICONMAP} } = split( /\s+/, <$icons> );
                $icons->close();
            }
            catch Error with {
                ASSERT( 0, $_[0] ) if DEBUG;
                %{ $this->{_ICONMAP} } = ();
            };
        }
        else {
            return $default || $fileName;
        }
    }

    return $this->{_ICONMAP}->{$fileExt} || $default || 'else';
}

sub ICON {
    my ( $this, $params ) = @_;
    my $file = $params->{_DEFAULT} || '';
    my $alt = defined $params->{alt} ? $params->{alt} : $file;

    # Try to map the file name to see if there is a matching filetype image
    # If no mapping could be found, use the file name that was passed
    my $iconFileName = $this->mapToIconFileName( $file, $alt );
    return '' unless $iconFileName;
    return $this->renderer->renderIconImage(
        $this->getIconUrl( 0, $iconFileName ),
        $iconFileName );
}

1;
__DATA__
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
